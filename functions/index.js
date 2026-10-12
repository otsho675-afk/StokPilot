'use strict';
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('node:crypto');
const { lineAmount, balanceDelta } = require('./math');
const { canCreateProduct, isProActive, FREE_PRODUCT_LIMIT } = require('./plan');
admin.initializeApp();
const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;
const webhookSecret = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const region = 'europe-west1';
const root = uid => db.collection('workspaces').doc(uid);
const deny = (code, message) => { throw new HttpsError(code, message); };
function uidOf(req) { if (!req.auth?.uid) deny('unauthenticated', 'Giris yapin.'); return req.auth.uid; }
function text(v, max = 150) { return typeof v === 'string' ? v.trim().slice(0, max) : ''; }
function int(v, min = 0, max = Number.MAX_SAFE_INTEGER) {
  if (!Number.isSafeInteger(v) || v < min || v > max) deny('invalid-argument', 'Gecersiz sayisal deger.');
  return v;
}
// 50 products are included in the free plan. Sales, stock and ledger remain free.
function requireWorkspace(snapshot) {
  if (!snapshot.exists) deny('failed-precondition', 'Isletme kurulumunu tamamlayin.');
}

exports.initializeWorkspace = onCall({ region }, async req => {
  const uid = uidOf(req);
  const name = text(req.data?.name, 100) || 'Isletmem';
  const ws = root(uid);
  const ent = ws.collection('entitlements').doc('current');
  await db.runTransaction(async tx => {
    const [workspace, subscription] = await Promise.all([tx.get(ws), tx.get(ent)]);
    if (!workspace.exists) tx.create(ws, { ownerUid: uid, name, currency: 'TRY', productCount: 0, createdAt: Timestamp.now() });
    // Existing 14-day trial accounts become free; only verified store purchases grant Pro.
    if (!subscription.exists) tx.create(ent, { status: 'free', source: 'free', eventAtMs: 0, updatedAt: Timestamp.now() });
  });
  return { ok: true };
});

// Product creation is exclusively server-side. A Firestore transaction owns the counter
// so two simultaneous devices cannot both add product #51 on a free workspace.
exports.createProduct = onCall({ region }, async req => {
  const uid = uidOf(req);
  const d = req.data || {};
  const name = text(d.name, 150);
  if (!name) deny('invalid-argument', 'Urun adi zorunlu.');
  const product = {
    name, sku: text(d.sku, 80), barcode: text(d.barcode, 80),
    categoryId: text(d.categoryId, 128), unitId: text(d.unitId, 128),
    taxRateBps: int(d.taxRateBps, 0, 10000),
    purchasePriceMinor: int(d.purchasePriceMinor, 0, 1e12),
    salePriceMinor: int(d.salePriceMinor, 0, 1e12),
    minStockMilli: int(d.minStockMilli, 0, 1e12),
    isActive: d.isActive !== false,
    stockMilli: 0,
    createdAt: Timestamp.now(),
  };
  const ws = root(uid), entRef = ws.collection('entitlements').doc('current');
  const ref = ws.collection('products').doc();
  // Count backfill accommodates workspaces made with older versions.
  const previous = await ws.get();
  if (!previous.exists) deny('failed-precondition', 'Isletmeyi baslatin.');
  let oldCount = previous.data().productCount;
  if (!Number.isSafeInteger(oldCount) || oldCount < 0) {
    const countSnap = await ws.collection('products').count().get();
    oldCount = countSnap.data().count;
  }
  await db.runTransaction(async tx => {
    const [workspace, ent] = await Promise.all([tx.get(ws), tx.get(entRef)]);
    requireWorkspace(workspace);
    // Treat the backfill count as the minimum to avoid undercounting old products.
    const stored = workspace.data().productCount;
    const currentCount = Number.isSafeInteger(stored) && stored >= 0 ? stored : oldCount;
    if (!canCreateProduct(currentCount, isProActive(ent.exists ? ent.data() : null, Date.now()))) {
      deny('resource-exhausted', `Ucretsiz planda en fazla ${FREE_PRODUCT_LIMIT} urun eklenebilir. StokPilot Pro aboneligi alin.`);
    }
    tx.create(ref, product);
    tx.update(ws, { productCount: currentCount + 1 });
  });
  return { id: ref.id };
});

// Currency: integer kurus. Quantities: integer milli-units (1.250 pcs = 1250).
// Tax: integer basis points (20% = 2000). All stock and ledger changes server-side.
exports.commitTrade = onCall({ region }, async req => {
  const uid = uidOf(req);
  const { type, contactId, lines, paidMinor = 0, note = '' } = req.data || {};
  if (!['sale', 'purchase'].includes(type) || !Array.isArray(lines) || !lines.length || lines.length > 50) deny('invalid-argument', 'Islem turu veya satirlar gecersiz.');
  int(paidMinor);
  const ids = lines.map(l => text(l.productId, 128));
  if (ids.some(id => !id) || new Set(ids).size !== ids.length) deny('invalid-argument', 'Ayni urun bir kez eklenebilir.');
  const ws = root(uid);
  const contactRef = contactId ? ws.collection('contacts').doc(text(contactId, 128)) : null;
  const productRefs = ids.map(id => ws.collection('products').doc(id));
  const tradeRef = ws.collection('trades').doc();
  await db.runTransaction(async tx => {
    const [contact, ...products] = await Promise.all([
      contactRef ? tx.get(contactRef) : Promise.resolve(null),
      ...productRefs.map(ref => tx.get(ref)),
    ]);
    if (contactRef && !contact?.exists) deny('not-found', 'Cari bulunamadi.');
    let netMinor = 0, taxMinor = 0, totalMinor = 0;
    const normalized = [];
    lines.forEach((line, i) => {
      const product = products[i];
      if (!product.exists || product.data().isActive === false) deny('not-found', 'Urun bulunamadi.');
      const quantityMilli = int(line.quantityMilli, 1, 1e12);
      const priceMinor = int(line.priceMinor, 0, 1e12);
      const taxBps = int(product.data().taxRateBps, 0, 10000);
      const { net, tax, gross } = lineAmount(quantityMilli, priceMinor, taxBps);
      if (!Number.isSafeInteger(gross) || gross > 1e12) deny('invalid-argument', 'Tutar limiti asildi.');
      const stock = int(product.data().stockMilli, 0);
      if (type === 'sale' && stock < quantityMilli) deny('failed-precondition', `Yetersiz stok: ${product.data().name}`);
      const nextStock = type === 'sale' ? stock - quantityMilli : stock + quantityMilli;
      tx.update(productRefs[i], { stockMilli: nextStock });
      const move = ws.collection('stockMoves').doc();
      tx.create(move, { productId: ids[i], tradeId: tradeRef.id, deltaMilli: type === 'sale' ? -quantityMilli : quantityMilli, reason: type, createdAt: Timestamp.now() });
      normalized.push({ productId: ids[i], name: product.data().name, quantityMilli, priceMinor, taxBps, netMinor: net, taxMinor: tax, totalMinor: gross });
      netMinor += net; taxMinor += tax; totalMinor += gross;
    });
    if (paidMinor > totalMinor) deny('invalid-argument', 'Odeme tutari toplami asamaz.');
    if (!contactRef && paidMinor !== totalMinor) deny('invalid-argument', 'Veresiye icin cari secin.');
    const balanceChange = balanceDelta(type, totalMinor, paidMinor);
    if (contactRef) tx.update(contactRef, { balanceMinor: (contact.data().balanceMinor || 0) + balanceChange });
    tx.create(tradeRef, { type, contactId: contactRef?.id || null, lines: normalized, paidMinor, netMinor, taxMinor, totalMinor, note: text(note, 1000), createdAt: Timestamp.now() });
    if (paidMinor > 0) tx.create(ws.collection('payments').doc(), { contactId: contactRef?.id || null, tradeId: tradeRef.id, type: type === 'sale' ? 'collection' : 'payout', amountMinor: paidMinor, createdAt: Timestamp.now(), auto: true });
  });
  return { id: tradeRef.id };
});
exports.postPayment = onCall({ region }, async req => {
  const uid = uidOf(req);
  const contactId = text(req.data?.contactId, 128);
  const type = req.data?.type;
  const amountMinor = int(req.data?.amountMinor, 1, 1e12);
  if (!contactId || !['collection', 'payout'].includes(type)) deny('invalid-argument', 'Odeme gecersiz.');
  const ws = root(uid), cr = ws.collection('contacts').doc(contactId);
  const pr = ws.collection('payments').doc();
  await db.runTransaction(async tx => {
    const contact = await tx.get(cr);
    if (!contact.exists) deny('not-found', 'Cari bulunamadi.');
    const delta = type === 'collection' ? -amountMinor : amountMinor;
    tx.update(cr, { balanceMinor: (contact.data().balanceMinor || 0) + delta });
    tx.create(pr, { contactId, tradeId: null, type, amountMinor, createdAt: Timestamp.now(), auto: false });
  });
  return { id: pr.id };
});
exports.adjustStock = onCall({ region }, async req => {
  const uid = uidOf(req);
  const id = text(req.data?.productId, 128);
  const deltaMilli = req.data?.deltaMilli;
  if (!id || !Number.isSafeInteger(deltaMilli) || deltaMilli === 0 || Math.abs(deltaMilli) > 1e12) deny('invalid-argument', 'Stok degisimi gecersiz.');
  const ws = root(uid), pr = ws.collection('products').doc(id);
  await db.runTransaction(async tx => {
    const product = await tx.get(pr);
    if (!product.exists) deny('not-found', 'Urun bulunamadi.');
    const next = (product.data().stockMilli || 0) + deltaMilli;
    if (next < 0) deny('failed-precondition', 'Stok eksiye dusemez.');
    tx.update(pr, { stockMilli: next });
    tx.create(ws.collection('stockMoves').doc(), { productId: id, tradeId: null, deltaMilli, reason: 'adjustment', note: text(req.data?.note, 250), createdAt: Timestamp.now() });
  });
  return { ok: true };
});

// RevenueCat webhook is the ONLY paid entitlement writer. RevenueCat verifies store receipts.
// Cancellation does not revoke until paid-through expiry. Duplicate/out-of-order events handled.
exports.revenueCatWebhook = onRequest({ region, secrets: [webhookSecret] }, async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('method');
  const expected = Buffer.from(`Bearer ${webhookSecret.value()}`);
  const actual = Buffer.from(req.get('authorization') || '');
  if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) return res.status(401).send('unauthorized');
  const e = req.body?.event;
  if (!e || typeof e.id !== 'string' || typeof e.app_user_id !== 'string' || !e.type) return res.status(400).send('payload');
  const uid = e.app_user_id;
  // We deliberately avoid linking RevenueCat anonymous IDs to a different Firebase UID.
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(uid) || uid.startsWith('$RC')) return res.status(200).send('ignored');
  const ws = root(uid), entRef = ws.collection('entitlements').doc('current');
  const eventRef = ws.collection('billingEvents').doc(crypto.createHash('sha256').update(e.id).digest('hex'));
  const eventAtMs = Number.isSafeInteger(e.event_timestamp_ms) ? e.event_timestamp_ms : Date.now();
  const hasPro = Array.isArray(e.entitlement_ids) && e.entitlement_ids.includes('pro');
  const grant = ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE'].includes(e.type);
  const expire = e.type === 'EXPIRATION';
  // CANCELLATION, BILLING_ISSUE are observational, not immediate revocations.
  await db.runTransaction(async tx => {
    const [workspace, previous, duplicate] = await Promise.all([tx.get(ws), tx.get(entRef), tx.get(eventRef)]);
    if (duplicate.exists || !workspace.exists) return;
    tx.create(eventRef, { type: e.type, at: Timestamp.fromMillis(eventAtMs), createdAt: Timestamp.now() });
    if ((!grant && !expire) || (grant && !hasPro)) return;
    const before = previous.exists ? previous.data() : {};
    if (eventAtMs < (before.eventAtMs || 0)) return;
    const expiresMs = Number.isSafeInteger(e.expiration_at_ms) ? e.expiration_at_ms : 0;
    if (grant && expiresMs <= Date.now()) return;
    tx.set(entRef, { status: expire ? 'expired' : 'active', source: 'revenuecat', expiresAt: Timestamp.fromMillis(expire ? 0 : expiresMs), productId: text(e.product_id), eventAtMs, updatedAt: Timestamp.now() }, { merge: true });
  });
  return res.status(200).send('ok');
});

// Account deletion endpoint for Apple App Store / Google Play policy compliance.
// Require a very recent login and explicitly confirm from the client.
exports.deleteAccount = onCall({ region, timeoutSeconds: 120, memory: '512MiB' }, async req => {
  const uid = uidOf(req);
  if (req.data?.confirm !== 'HESABIMI SIL') deny('invalid-argument', 'Onay metni eksik.');
  const authTime = req.auth?.token?.auth_time;
  if (typeof authTime !== 'number' || Date.now() / 1000 - authTime > 300) {
    deny('failed-precondition', 'Hesap silmek icin son 5 dakika icinde yeniden giris yapin.');
  }
  await db.recursiveDelete(root(uid));
  await admin.auth().deleteUser(uid);
  return { ok: true };
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { playState, appleState, appleStatus } from './src/index.js';
import { appleRootCAs } from './src/apple-roots.js';
import { appleAccountToken, appleProofClaims, ensureOcspResponseBuffer,
  persist, verifyApplePurchaseProof } from './src/direct-store.js';
const now = Date.parse('2026-10-16T12:00:00Z');
const future = new Date(now + 30 * 86400000).toISOString();
const item = { productId: 'stokpilot_pro_monthly', expiryTime: future };
test('Play active subscription grants verified expiry', () => {
  assert.equal(playState({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE', lineItems: [item] }, now).expiresMs,
    Date.parse(future));
});
test('Play canceled retains prepaid days but pending/on-hold not granted', () => {
  for (const state of ['SUBSCRIPTION_STATE_CANCELED', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD']) {
    assert.equal(playState({ subscriptionState: state, lineItems: [item] }, now).expiresMs, Date.parse(future));
  }
  for (const state of ['SUBSCRIPTION_STATE_PENDING', 'SUBSCRIPTION_STATE_ON_HOLD', 'SUBSCRIPTION_STATE_EXPIRED']) {
    assert.equal(playState({ subscriptionState: state, lineItems: [item] }, now).expiresMs, 0);
  }
});
test('Play never grants an unrelated SKU', () => {
  assert.throws(() => playState({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [{...item, productId: 'other'}]}, now), /mismatch/);
});
const jws = (payload) => 'e30.' + Buffer.from(JSON.stringify(payload)).toString('base64url') + '.signature';
const fakeVerifier = {
  async verifyAndDecodeTransaction(value) { return JSON.parse(Buffer.from(value.split('.')[1], 'base64url')); },
  async verifyAndDecodeRenewalInfo(value) { return JSON.parse(Buffer.from(value.split('.')[1], 'base64url')); },
};
const appleInfo = { bundleId: 'com.yesildas.stokpilot',
  productId: 'stokpilot_pro_monthly', originalTransactionId: '1000012345',
  appAppleId: 123456789, expiresDate: now + 2000000 };
test('Apple active and grace statuses grant Pro; expired/refunded/revoked denied', async () => {
  const input = (status, overrides = {}, grace = now + 4000000) => ({ data: [{ lastTransactions: [{
    status, signedTransactionInfo: jws({...appleInfo, ...overrides}),
    signedRenewalInfo: jws({originalTransactionId: appleInfo.originalTransactionId,
      productId: appleInfo.productId,
      gracePeriodExpiresDate: grace}),
  }] }] });
  const state = (value, original = null) => appleState(value, appleInfo.bundleId,
    fakeVerifier, original, now, appleInfo.appAppleId);
  assert.equal((await state(input(1))).expiresMs, appleInfo.expiresDate);
  assert.equal((await state(input(4))).expiresMs, now + 4000000);
  assert.equal((await state(input(4, {}, now - 1))).expiresMs, 0);
  assert.equal((await state(input(5))).expiresMs, 0);
  assert.equal((await state(input(1, { revocationDate: now }))).expiresMs, 0);
  await assert.rejects(state(input(1, { bundleId: 'com.example.other' })));
  await assert.rejects(state(input(1, { productId: 'unrelated' })));
  await assert.rejects(state(input(1, { appAppleId: 999999999 })));
  await assert.rejects(state(input(1), '100008888'));
  const mismatched = input(4);
  mismatched.data[0].lastTransactions[0].signedRenewalInfo = jws({
    originalTransactionId: '1000099999', productId: appleInfo.productId,
    gracePeriodExpiresDate: now + 4000000,
  });
  await assert.rejects(state(mismatched), /mismatch/);
  const otherProduct = input(4);
  otherProduct.data[0].lastTransactions[0].signedRenewalInfo = jws({
    originalTransactionId: appleInfo.originalTransactionId, productId: 'other',
    gracePeriodExpiresDate: now + 4000000,
  });
  await assert.rejects(state(otherProduct), /product mismatch/);
});

test('Apple status ignores other subscription products without hiding Pro', async () => {
  const unrelated = { status: 1, signedTransactionInfo: jws({
    ...appleInfo, productId: 'another_subscription', originalTransactionId: '1000099999',
  }) };
  const pro = { status: 1, signedTransactionInfo: jws(appleInfo) };
  const response = { data: [
    { lastTransactions: [unrelated] }, { lastTransactions: [pro] },
  ] };
  const state = await appleState(response, appleInfo.bundleId, fakeVerifier,
    appleInfo.originalTransactionId, now, appleInfo.appAppleId);
  assert.equal(state.lookup, appleInfo.originalTransactionId);
  assert.equal(state.expiresMs, appleInfo.expiresDate);
  await assert.rejects(appleState({ data: [{ lastTransactions: [unrelated] }] },
    appleInfo.bundleId, fakeVerifier, null, now, appleInfo.appAppleId), /not found/);
});

test('Apple signed transaction payload cannot be forged by editing its JSON', async () => {
  const verifier = new SignedDataVerifier(appleRootCAs, false, Environment.SANDBOX,
    appleInfo.bundleId);
  await assert.rejects(appleState({data: [{lastTransactions: [{status: 1,
    signedTransactionInfo: jws(appleInfo)}]}]}, appleInfo.bundleId, verifier, null, now));
});

test('StoreKit 2 proof checks signed purchase, app and transaction identity', async () => {
  const transactionId = '1000012444';
  const tx = { ...appleInfo, transactionId, environment: 'Sandbox' };
  assert.equal(appleProofClaims(tx, transactionId, appleInfo.bundleId,
    appleInfo.appAppleId), tx);
  assert.throws(() => appleProofClaims({ ...tx, transactionId: '1000099999' },
    transactionId, appleInfo.bundleId, appleInfo.appAppleId), /transaction ID mismatch/);
  assert.throws(() => appleProofClaims({ ...tx, appAppleId: 9 },
    transactionId, appleInfo.bundleId, appleInfo.appAppleId), /app ID mismatch/);
  assert.throws(() => appleProofClaims({ ...tx, productId: 'other' },
    transactionId, appleInfo.bundleId, appleInfo.appAppleId), /product/);
  assert.throws(() => appleProofClaims({ ...tx, environment: 'Production', appAppleId: null },
    transactionId, appleInfo.bundleId, appleInfo.appAppleId), /app ID/);
  await assert.rejects(verifyApplePurchaseProof(jws(tx), transactionId, {
    APPLE_BUNDLE_ID: appleInfo.bundleId, APPLE_APP_ID: String(appleInfo.appAppleId),
  }), /./); // An unsigned payload with correct claims is still rejected.
  await assert.rejects(verifyApplePurchaseProof(null, transactionId, {
    APPLE_BUNDLE_ID: appleInfo.bundleId, APPLE_APP_ID: String(appleInfo.appAppleId),
  }), /signed transaction/);
});

test('Apple account token matches Flutter UUIDv5 and deletion-only restore policy', async () => {
  assert.equal(await appleAccountToken('test-user-123'),
    'ddea7c8d-89e5-56a5-b5fb-d529f662bd15');
  const uid = 'new-user';
  const oldUid = 'old-user';
  const originalFetch = globalThis.fetch;
  let oldWorkspaceDeleted = false;
  let bindingExists = true;
  let bindingUid = oldUid;
  let storedAccountToken = '';
  let commits = 0;
  globalThis.fetch = async (url, options = {}) => {
    const path = String(url);
    if (path.endsWith(':commit')) {
      commits++;
      const writes = JSON.parse(options.body).writes;
      assert.equal(writes[0].update.fields.uid.stringValue, uid);
      bindingUid = writes[0].update.fields.uid.stringValue;
      storedAccountToken = writes[0].update.fields.accountToken?.stringValue ?? '';
      return new Response('{}');
    }
    if (path.endsWith('/workspaces/' + uid)) {
      return Response.json({ fields: { name: { stringValue: 'New account' } } });
    }
    if (path.endsWith('/workspaces/' + oldUid)) {
      return Response.json({ fields: oldWorkspaceDeleted ? {
        deletedAt: { timestampValue: new Date(now).toISOString() },
      } : { name: { stringValue: 'Live account' } } });
    }
    if (path.includes('/billingPurchases/')) {
      return bindingExists ? Response.json({
        updateTime: new Date(now).toISOString(), fields: {
          uid: { stringValue: bindingUid },
          ...(storedAccountToken ? { accountToken: { stringValue: storedAccountToken } } : {}),
        },
      }) : new Response(null, { status: 404 });
    }
    return new Response(null, { status: 404 });
  };
  try {
    const env = { FIREBASE_PROJECT_ID: 'test-project' };
    const state = { lookup: appleInfo.originalTransactionId, expiresMs: now + 1e12 };
    const proof = { appAccountToken: await appleAccountToken(oldUid) };
    assert.equal((await persist(env, 'access', uid, 'ios', state, proof)).status, 409);
    assert.equal(commits, 0);
    oldWorkspaceDeleted = true;
    assert.equal((await persist(env, 'access', uid, 'ios', state, proof)).status, 200);
    assert.equal(commits, 1);
    assert.equal(storedAccountToken, proof.appAccountToken);
    // A second restore after the rebind still carries Apple's original token.
    assert.equal((await persist(env, 'access', uid, 'ios', state, proof)).status, 200);
    assert.equal(commits, 2);
    assert.equal((await persist(env, 'access', uid, 'ios', state,
      { appAccountToken: await appleAccountToken(uid) })).status, 409);
    assert.equal((await persist(env, 'access', uid, 'ios', state,
      { appAccountToken: null })).status, 409);
    bindingExists = false;
    assert.equal((await persist(env, 'access', uid, 'ios', state,
      { appAccountToken: null })).status, 409);
    assert.equal(commits, 2);
    assert.equal((await persist(env, 'access', uid, 'ios', state,
      { appAccountToken: await appleAccountToken(oldUid) })).status, 409);
    assert.equal((await persist(env, 'access', uid, 'ios', state,
      { appAccountToken: await appleAccountToken(uid) })).status, 200);
    assert.equal(commits, 3);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Apple OCSP response adapter preserves binary bytes in Workers Fetch', async () => {
  ensureOcspResponseBuffer();
  const response = new Response(Uint8Array.of(0, 127, 255));
  const ocsp = await response.buffer();
  assert.ok(Buffer.isBuffer(ocsp));
  assert.equal(ocsp.toString('hex'), '007fff');
  ensureOcspResponseBuffer(); // Repeated purchase checks do not replace the adapter.
  assert.equal((await new Response(Uint8Array.of(42)).buffer()).toString('hex'), '2a');
});

test('Apple production 401 falls back to sandbox without granting an unknown purchase', async () => {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const originalFetch = globalThis.fetch;
  const hosts = [];
  globalThis.fetch = async (url) => {
    hosts.push(new URL(url).host);
    return new Response(null, { status: hosts.length === 1 ? 401 : 404 });
  };
  try {
    await assert.rejects(appleStatus('1000012345', {
      APPLE_ISSUER_ID: 'test-issuer', APPLE_KEY_ID: 'TESTKEY',
      APPLE_PRIVATE_KEY: privateKey.export({ type: 'pkcs8', format: 'pem' }),
      APPLE_BUNDLE_ID: appleInfo.bundleId, APPLE_APP_ID: String(appleInfo.appAppleId),
    }), /Apple transaction not found/);
    assert.deepEqual(hosts, ['api.storekit.apple.com', 'api.storekit-sandbox.apple.com']);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

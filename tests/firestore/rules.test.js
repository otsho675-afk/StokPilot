const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, collection, runTransaction, getDoc, setDoc, updateDoc, serverTimestamp, writeBatch, Timestamp } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-stokpilot',
    firestore: {
      host: '127.0.0.1', port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});
after(async () => { if (env) await env.cleanup(); });

const newProduct = () => ({
  name: 'Ürün', sku: '', barcode: '', categoryId: '', unitId: '',
  taxRateBps: 2000, purchasePriceMinor: 100, salePriceMinor: 150,
  minStockMilli: 0, stockMilli: 0, isActive: true,
  createdAt: serverTimestamp(),
});

test('Spark: guest creates 50 items, blocks #51 and cross-account reads', async () => {
  const db = env.authenticatedContext('owner-one', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
  const workspace = doc(db, 'workspaces/owner-one');
  await assertSucceeds(setDoc(workspace, {
    ownerUid: 'owner-one', name: 'My business', currency: 'TRY',
    productCount: 0, createdAt: serverTimestamp(),
  }));
  for (let i = 0; i < 50; i++) {
    const item = doc(collection(db, 'workspaces/owner-one/products'));
    await assertSucceeds(runTransaction(db, async tx => {
      const current = await tx.get(workspace);
      tx.set(item, newProduct());
      tx.update(workspace, {
        productCount: current.data().productCount + 1,
        lastProductId: item.id,
      });
    }));
  }
  assert.equal((await getDoc(workspace)).data().productCount, 50);
  const forbidden = doc(collection(db, 'workspaces/owner-one/products'));
  await assertFails(runTransaction(db, async tx => {
    const current = await tx.get(workspace);
    tx.set(forbidden, newProduct());
    tx.update(workspace, {
      productCount: current.data().productCount + 1,
      lastProductId: forbidden.id,
    });
  }));
  await assertFails(updateDoc(workspace, { productCount: 0 }));
  // Prevent quota resetting by deleting and recreating the workspace.
  const { deleteDoc } = require('firebase/firestore');
  await assertFails(deleteDoc(workspace));
  const other = env.authenticatedContext('other-user').firestore();
  await assertFails(getDoc(doc(other, 'workspaces/owner-one')));
});

test('Spark: cannot create two products with a single counter increment', async () => {
  const db = env.authenticatedContext('counter-test').firestore();
  const ws = doc(db, 'workspaces/counter-test');
  await assertSucceeds(setDoc(ws, {
    ownerUid: 'counter-test', name: 'Second business', currency: 'TRY',
    productCount: 0, createdAt: serverTimestamp(),
  }));
  const a = doc(collection(db, 'workspaces/counter-test/products'));
  const b = doc(collection(db, 'workspaces/counter-test/products'));
  const batch = writeBatch(db);
  batch.set(a, newProduct());
  batch.set(b, newProduct());
  batch.update(ws, { productCount: 1, lastProductId: a.id });
  await assertFails(batch.commit());
});


test('sale settlement rules distinguish cash, card and veresiye', async () => {
  const db = env.authenticatedContext('payment-test-owner').firestore();
  await assertSucceeds(setDoc(doc(db, 'workspaces/payment-test-owner'), {
    ownerUid: 'payment-test-owner', name: 'Shop', currency: 'TRY',
    productCount: 0, createdAt: serverTimestamp(),
  }));
  const base = {
    type: 'sale', contactId: null, lines: [{productId: 'p', quantityMilli: 1000}],
    paidMinor: 12000, netMinor: 10000, taxMinor: 2000, totalMinor: 12000,
    note: '', createdAt: serverTimestamp(),
  };
  const ref = () => doc(collection(db, 'workspaces/payment-test-owner/trades'));
  await assertSucceeds(setDoc(ref(), {...base, paymentMethod: 'cash'}));
  await assertSucceeds(setDoc(ref(), {...base, paymentMethod: 'card'}));
  await assertSucceeds(setDoc(ref(), {
    ...base, paidMinor: 0, contactId: 'customer-1', paymentMethod: 'credit',
  }));
  await assertFails(setDoc(ref(), {...base, paidMinor: 0, paymentMethod: 'cash'}));
  await assertFails(setDoc(ref(), {...base, paidMinor: 0, paymentMethod: 'card'}));
  await assertFails(setDoc(ref(), {...base, paidMinor: 0, paymentMethod: 'credit'}));
  await assertFails(setDoc(ref(), {
    ...base, paidMinor: 12000, contactId: 'customer-1', paymentMethod: 'credit',
  }));
  await assertFails(setDoc(ref(), {...base, paymentMethod: 'crypto'}));
});

test('expenses require owned, valid records and block updates', async () => {
  const db = env.authenticatedContext('expense-owner').firestore();
  const ref = () => doc(collection(db, 'workspaces/expense-owner/expenses'));
  const valid = {title: 'Kira', category: 'rent', method: 'bank',
    amountMinor: 500000, note: '', createdAt: serverTimestamp()};
  const expense = ref();
  await assertSucceeds(setDoc(expense, valid));
  await assertSucceeds(getDoc(expense));
  await assertFails(setDoc(ref(), {...valid, amountMinor: -1}));
  await assertFails(setDoc(ref(), {...valid, category: 'invalid'}));
  await assertFails(updateDoc(expense, {amountMinor: 1}));
  await assertSucceeds(require('firebase/firestore').deleteDoc(expense));
  const other = env.authenticatedContext('another-user').firestore();
  await assertFails(getDoc(doc(other, expense.path)));
});

test('historical debt records validate amount, date and ownership', async () => {
  const db = env.authenticatedContext('debt-owner').firestore();
  const ref = () => doc(collection(db, 'workspaces/debt-owner/accountEntries'));
  const valid = {
    contactId: 'supplier-1', kind: 'supplierDebt', documentKind: 'invoice',
    reference: 'F-2025-42', projectName: '', note: 'Geçmiş bakiye',
    amountMinor: 125000, settledMinor: 0,
    effectiveAt: Timestamp.fromDate(new Date('2025-08-01T00:00:00Z')),
    createdAt: serverTimestamp(),
  };
  const entry = ref();
  await assertSucceeds(setDoc(entry, valid));
  await assertSucceeds(getDoc(entry));
  await assertFails(setDoc(ref(), {...valid, amountMinor: 0}));
  await assertFails(setDoc(ref(), {...valid, documentKind: 'unknown'}));
  await assertSucceeds(updateDoc(entry, {settledMinor: 50000}));
  await assertFails(updateDoc(entry, {settledMinor: 130000}));
  await assertFails(updateDoc(entry, {amountMinor: 1}));
  const other = env.authenticatedContext('other-debt-user').firestore();
  await assertFails(getDoc(doc(other, entry.path)));
});

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, collection, runTransaction, getDoc, setDoc, updateDoc, serverTimestamp, writeBatch } = require('firebase/firestore');

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

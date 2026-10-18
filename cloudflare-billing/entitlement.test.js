import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { playState, appleState, appleStatus } from './src/index.js';
import { appleRootCAs } from './src/apple-roots.js';
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
    originalTransactionId: '1000099999', gracePeriodExpiresDate: now + 4000000,
  });
  await assert.rejects(state(mismatched), /mismatch/);
});

test('Apple signed transaction payload cannot be forged by editing its JSON', async () => {
  const verifier = new SignedDataVerifier(appleRootCAs, false, Environment.SANDBOX,
    appleInfo.bundleId);
  await assert.rejects(appleState({data: [{lastTransactions: [{status: 1,
    signedTransactionInfo: jws(appleInfo)}]}]}, appleInfo.bundleId, verifier, null, now));
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

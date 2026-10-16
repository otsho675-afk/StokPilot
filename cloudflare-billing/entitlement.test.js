import { test } from 'node:test';
import assert from 'node:assert/strict';
import { playState, appleState } from './src/index.js';
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
const appleInfo = { bundleId: 'com.yesildas.stokpilot',
  productId: 'stokpilot_pro_monthly', originalTransactionId: '1000012345',
  expiresDate: now + 2000000 };
test('Apple active and grace statuses grant Pro; refunded/revoked denied', () => {
  const input = (status, overrides = {}) => ({ data: [{ lastTransactions: [{
    status, signedTransactionInfo: jws({...appleInfo, ...overrides}),
  }] }] });
  assert.equal(appleState(input(1), appleInfo.bundleId, null, now).expiresMs, appleInfo.expiresDate);
  assert.equal(appleState(input(4), appleInfo.bundleId, null, now).expiresMs, appleInfo.expiresDate);
  assert.equal(appleState(input(5), appleInfo.bundleId, null, now).expiresMs, 0);
  assert.equal(appleState(input(1, { revocationDate: now }), appleInfo.bundleId, null, now).expiresMs, 0);
  assert.throws(() => appleState(input(1, { bundleId: 'com.example.other' }), appleInfo.bundleId, null, now));
  assert.throws(() => appleState(input(1, { productId: 'unrelated' }), appleInfo.bundleId, null, now));
  assert.throws(() => appleState(input(1), appleInfo.bundleId, '100008888', now));
});

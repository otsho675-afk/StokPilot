import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker, {evaluateAppleStatus, evaluateGoogleSubscription} from './src/index.js';

const now = Date.UTC(2026, 9, 16);
const product = 'stokpilot_pro_monthly';
function appleTransaction(overrides = {}) {
  const transaction = {
    bundleId:'com.yesildas.stokpilot',
    productId:product,
    type:'Auto-Renewable Subscription',
    originalTransactionId:'123456789012345',
    expiresDate:now + 3600000,
    ...overrides,
  };
  return `eyJhbGciOiJFUzI1NiJ9.${Buffer.from(JSON.stringify(transaction)).toString('base64url')}.signature`;
}
const appleResponse = (signedTransactionInfo, status=1) => ({
  data:[{lastTransactions:[{status, signedTransactionInfo}]}],
});
test('Apple active subscription from server response', () => {
  assert.deepEqual(evaluateAppleStatus(appleResponse(appleTransaction()),
    'com.yesildas.stokpilot', now), {
    platform:'ios', purchaseKey:'ios:123456789012345', expiresMs:now+3600000,
  });
});
test('Apple revoked, expired, wrong app and wrong product never grant Pro', () => {
  for(const change of [
    {revocationDate:now}, {expiresDate:now-1},
    {productId:'other'}, {bundleId:'another.app'},
    {type:'Non-Consumable'},
  ]) assert.equal(evaluateAppleStatus(appleResponse(appleTransaction(change)),
    'com.yesildas.stokpilot', now), null);
  assert.equal(evaluateAppleStatus(appleResponse(appleTransaction(), 5),
    'com.yesildas.stokpilot', now), null);
});
test('Google supports paid canceled period but rejects on-hold or expired', () => {
  const subscription = {
    subscriptionState:'SUBSCRIPTION_STATE_ACTIVE',
    lineItems:[{productId:product, expiryTime:new Date(now+3600000).toISOString()}],
  };
  assert.deepEqual(evaluateGoogleSubscription(subscription, now), {
    platform:'android', expiresMs:now+3600000,
  });
  assert.ok(evaluateGoogleSubscription({...subscription,
    subscriptionState:'SUBSCRIPTION_STATE_CANCELED'},now));
  assert.ok(evaluateGoogleSubscription({...subscription,
    subscriptionState:'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'},now));
  assert.equal(evaluateGoogleSubscription({...subscription,
    subscriptionState:'SUBSCRIPTION_STATE_ON_HOLD'},now), null);
  assert.equal(evaluateGoogleSubscription({...subscription,
    lineItems:[{productId:product,expiryTime:new Date(now-1).toISOString()}]},now),null);
  assert.equal(evaluateGoogleSubscription({...subscription,
    lineItems:[{productId:'another',expiryTime:new Date(now+3600000).toISOString()}]},now),null);
});
test('unconfigured worker never grants entitlement', async () => {
  const response = await worker.fetch(new Request('https://billing.example/verify', {
    method:'POST',headers:{authorization:'Bearer fake','content-type':'application/json'},
    body:JSON.stringify({platform:'ios',productId:product,proof:'1234567890'}),
  }), {});
  assert.equal(response.status,503);
  assert.equal((await response.json()).error, 'billing_not_configured');
});
test('legacy RevenueCat webhook is removed', async () => {
  const response = await worker.fetch(new Request('https://billing.example/revenuecat',{
    method:'POST',body:'{}',
  }), {});
  assert.equal(response.status,404);
});

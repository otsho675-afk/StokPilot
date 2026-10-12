import { test } from 'node:test';
import assert from 'node:assert/strict';
import { determineEntitlement } from './src/index.js';

const at = 1760000000000;
const event = {
  id: 'event-1', app_user_id: 'firebase-uid', product_id: 'stokpilot_pro_monthly',
  type: 'INITIAL_PURCHASE', entitlement_ids: ['pro'],
  event_timestamp_ms: at, expiration_at_ms: at + 300000,
};
test('valid store purchase gets Pro until its expiry', () => {
  assert.deepEqual(determineEntitlement(event, at), {
    status: 'active', atMs: at, expiresMs: at + 300000,
  });
});
test('does not grant Pro from invalid events', () => {
  assert.equal(determineEntitlement({...event, entitlement_ids: ['other']}, at), null);
  assert.equal(determineEntitlement({...event, expiration_at_ms: at - 1}, at), null);
  assert.equal(determineEntitlement({...event, product_id: 'other'}, at), null);
  assert.equal(determineEntitlement({...event, type: 'CANCELLATION'}, at), null);
});
test('expiration removes paid access', () => {
  assert.deepEqual(determineEntitlement({...event, type:'EXPIRATION'}, at), {
    status:'expired', atMs: at, expiresMs: 0,
  });
});

'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { canCreateProduct, isProActive } = require('./plan');
test('50 free products maximum, premium is unlimited', () => {
  assert.equal(canCreateProduct(0, false), true);
  assert.equal(canCreateProduct(49, false), true);
  assert.equal(canCreateProduct(50, false), false);
  assert.equal(canCreateProduct(51, false), false);
  assert.equal(canCreateProduct(500, true), true);
});
test('only unexpired RevenueCat grants pro (old trial does not)', () => {
  const at = 100000;
  assert.equal(isProActive({status:'trial', source:'trial', expiresAt: {toMillis:()=>at+10}},at),false);
  assert.equal(isProActive({status:'active', source:'revenuecat', expiresAt:{toMillis:()=>at+10}},at),true);
  assert.equal(isProActive({status:'active', source:'revenuecat', expiresAt:{toMillis:()=>at}},at),false);
});

'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { lineAmount, balanceDelta } = require('./math');
test('20% VAT on sale line 2 units × 125 TL', () => {
  assert.deepEqual(lineAmount(2000,12500,2000),{net:25000,tax:5000,gross:30000});
});
test('Three-decimal quantity precision', () => {
  assert.deepEqual(lineAmount(1250,10000,1000),{net:12500,tax:1250,gross:13750});
});
test('Sale increases customer receivable, purchase increases supplier payable', () => {
  assert.equal(balanceDelta('sale',30000,5000),25000);
  assert.equal(balanceDelta('purchase',30000,5000),-25000);
  assert.throws(()=>balanceDelta('sale',10000,11000));
});

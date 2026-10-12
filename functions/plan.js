'use strict';
const FREE_PRODUCT_LIMIT = 50;
function canCreateProduct(productCount, pro) {
  return pro || (Number.isSafeInteger(productCount) && productCount >= 0 && productCount < FREE_PRODUCT_LIMIT);
}
function isProActive(entitlement, nowMs) {
  if (!entitlement || entitlement.status !== 'active' || entitlement.source !== 'revenuecat') return false;
  const expiry = entitlement.expiresAt;
  return typeof expiry?.toMillis === 'function' && expiry.toMillis() > nowMs;
}
module.exports = { FREE_PRODUCT_LIMIT, canCreateProduct, isProActive };

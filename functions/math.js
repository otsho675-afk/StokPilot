'use strict';
const money = (qtyMilli, priceMinor) => Math.round(qtyMilli * priceMinor / 1000);
function lineAmount(qtyMilli, priceMinor, taxBps) {
  const net = money(qtyMilli, priceMinor);
  const tax = Math.round(net * taxBps / 10000);
  return { net, tax, gross: net + tax };
}
function balanceDelta(type, gross, paid) {
  if (paid < 0 || paid > gross) throw new Error('invalid payment');
  return (gross - paid) * (type === 'sale' ? 1 : -1);
}
module.exports = { money, lineAmount, balanceDelta };

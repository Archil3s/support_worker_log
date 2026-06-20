const assert = require('assert');
const {
  LOCATION,
  deriveUnitPrice,
  mergePriceHistory,
  normaliseUnitPrice,
  splitNameAndSize,
} = require('./grocery_scraper');

assert.strictEqual(LOCATION.city, 'Blenheim');
assert.strictEqual(LOCATION.region, 'Marlborough');

assert.deepStrictEqual(splitNameAndSize('Anchor Butter 500g'), {
  name: 'Anchor Butter',
  size: '500g',
});
assert.strictEqual(deriveUnitPrice('500g', 7.5), '15/kg');
assert.strictEqual(normaliseUnitPrice('$1.50 / 100g'), '15/kg');

const merged = mergePriceHistory(
  {
    products: [{
      id: '1',
      name: 'Eggs',
      sourceSite: 'newworld.co.nz',
      priceHistory: [{ date: '2020-01-01', price: 8 }],
    }],
  },
  [{
    id: '1',
    name: 'Eggs',
    size: '12pk',
    sourceSite: 'newworld.co.nz',
    category: 'eggs',
    currentPrice: 9,
    unitPrice: '',
  }],
);

assert.strictEqual(merged.products[0].priceHistory.length, 2);
assert.strictEqual(merged.products[0].priceHistory[1].price, 9);
assert.strictEqual(merged.location.city, 'Blenheim');

console.log('grocery_scraper tests passed');

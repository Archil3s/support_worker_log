const assert = require('assert');
const { validateCatalogue } = require('./refresh_grocery_catalogue');

const valid = {
  updatedAt: new Date().toISOString(),
  location: { city: 'Blenheim' },
  products: Array.from({ length: 100 }, (_, index) => ({ id: index })),
};

assert.strictEqual(validateCatalogue(valid), valid);
assert.throws(
  () => validateCatalogue({ ...valid, products: [] }),
  /contains only 0 products/,
);
assert.throws(
  () => validateCatalogue({
    ...valid,
    location: { city: 'Auckland' },
  }),
  /not linked to Blenheim/,
);

console.log('refresh_grocery_catalogue tests passed');

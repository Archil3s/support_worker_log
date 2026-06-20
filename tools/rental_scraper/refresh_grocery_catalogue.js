const {
  getGroceryCatalogue,
  startGroceryScrape,
} = require('./grocery_scraper');

function validateCatalogue(catalogue) {
  if (!catalogue || !Array.isArray(catalogue.products)) {
    throw new Error('Grocery catalogue has no product list.');
  }
  if (catalogue.products.length < 100) {
    throw new Error(
      `Grocery catalogue contains only ${catalogue.products.length} products.`,
    );
  }
  if (
    String(catalogue.location?.city || '').toLowerCase() !== 'blenheim'
  ) {
    throw new Error('Grocery catalogue is not linked to Blenheim.');
  }
  const updatedAt = Date.parse(catalogue.updatedAt || '');
  if (!Number.isFinite(updatedAt)) {
    throw new Error('Grocery catalogue has no valid update time.');
  }
  const ageHours = (Date.now() - updatedAt) / (60 * 60 * 1000);
  if (ageHours > 2) {
    throw new Error(
      `Grocery catalogue is ${ageHours.toFixed(1)} hours old after refresh.`,
    );
  }
  return catalogue;
}

async function main() {
  await startGroceryScrape();
  const catalogue = validateCatalogue(getGroceryCatalogue());
  console.log(
    `Saved ${catalogue.products.length} Blenheim products at ` +
      `${catalogue.updatedAt}.`,
  );
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { validateCatalogue };

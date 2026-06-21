const fs = require('fs');
const path = require('path');

const {
  LOCATION,
  getGroceryCatalogue,
  startGroceryScrape,
} = require('./grocery_scraper');

const DATA_PATH = path.join(__dirname, 'grocery_prices_blenheim.json');
const MINIMUM_PRODUCT_COUNT = 100;
const REQUIRED_SOURCES = [
  'countdown.co.nz',
  'paknsave.co.nz',
  'newworld.co.nz',
];
const MINIMUM_SOURCE_COUNT = 2;

async function main() {
  console.log('Starting scheduled Blenheim grocery scrape...');
  await startGroceryScrape();

  const catalogue = getGroceryCatalogue();
  validateCatalogue(catalogue);

  const counts = {};
  for (const product of catalogue.products) {
    counts[product.sourceSite] = (counts[product.sourceSite] || 0) + 1;
  }

  console.log(
    `Saved ${catalogue.products.length} Blenheim products to ${DATA_PATH}.`,
  );
  console.log(`Updated at ${catalogue.updatedAt}.`);
  console.log(`Products by source: ${JSON.stringify(counts)}.`);
}

function validateCatalogue(catalogue) {
  if (catalogue.location?.city !== LOCATION.city ||
      catalogue.location?.region !== LOCATION.region) {
    throw new Error('Scrape did not produce a Blenheim, Marlborough catalogue.');
  }

  if (!Array.isArray(catalogue.products) ||
      catalogue.products.length < MINIMUM_PRODUCT_COUNT) {
    throw new Error(
      `Scrape returned only ${catalogue.products?.length || 0} products.`,
    );
  }

  const updatedAt = Date.parse(catalogue.updatedAt || '');
  if (!Number.isFinite(updatedAt) || Date.now() - updatedAt > 30 * 60 * 1000) {
    throw new Error('Catalogue timestamp was not refreshed by this run.');
  }

  const availableSources = new Set(
    catalogue.products.map((product) => product.sourceSite),
  );
  const missingSources = REQUIRED_SOURCES.filter(
    (source) => !availableSources.has(source),
  );
  if (availableSources.size < MINIMUM_SOURCE_COUNT) {
    throw new Error(
      `Catalogue has only ${availableSources.size} supermarket source.`,
    );
  }
  if (missingSources.length > 0) {
    console.warn(
      `Continuing without temporarily unavailable sources: ` +
      `${missingSources.join(', ')}.`,
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

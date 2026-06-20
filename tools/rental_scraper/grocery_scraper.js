const fs = require('fs');
const path = require('path');

const DATA_PATH = path.join(__dirname, 'grocery_prices_blenheim.json');
const SCRAPE_INTERVAL_MS = 6 * 60 * 60 * 1000;
const MAX_PARALLEL_PAGES = 3;
const LOCATION = Object.freeze({
  city: 'Blenheim',
  region: 'Marlborough',
  country: 'New Zealand',
  latitude: -41.5134,
  longitude: 173.9612,
});

const state = {
  running: false,
  startedAt: null,
  completedAt: null,
  error: null,
  pagesCompleted: 0,
  pagesTotal: 0,
  stores: {},
  warning: null,
};

let activeScrape = null;

const grocerySources = [
  ...woolworthsSources(),
  ...foodstuffsSources('paknsave.co.nz', 'PAK\'nSAVE'),
  ...foodstuffsSources('newworld.co.nz', 'New World'),
];

function woolworthsSources() {
  const root = 'https://www.woolworths.co.nz/shop/browse';
  return [
    source('Woolworths', `${root}/meat-poultry/beef`, 'beef-lamb'),
    source('Woolworths', `${root}/meat-poultry/lamb`, 'beef-lamb'),
    source('Woolworths', `${root}/meat-poultry/chicken-poultry`, 'chicken'),
    source('Woolworths', `${root}/meat-poultry/pork`, 'pork'),
    source('Woolworths', `${root}/meat-poultry/sausages`, 'sausages'),
    source('Woolworths', `${root}/fish-seafood`, 'seafood'),
    source('Woolworths', `${root}/fridge-deli/eggs-butter-spreads/eggs`, 'eggs'),
    source('Woolworths', `${root}/fridge-deli/eggs-butter-spreads/butter`, 'butter'),
    source('Woolworths', `${root}/fridge-deli/cheese`, 'cheese'),
    source('Woolworths', `${root}/fridge-deli/cream-custard`, 'cream'),
    source('Woolworths', `${root}/fridge-deli/yoghurt-desserts`, 'yoghurt'),
    source('Woolworths', `${root}/fruit-veg/vegetables`, 'fresh-vegetables'),
    source('Woolworths', `${root}/pantry/oils-vinegars`, 'oils-vinegars'),
    source('Woolworths', `${root}/pantry/nuts-seeds`, 'nuts-bulk-mix'),
  ];
}

function foodstuffsSources(host, name) {
  const root = `https://www.${host}/shop/category`;
  return [
    source(name, `${root}/meat-poultry-and-seafood?pg=1&refinementList%5Bcategory1NI%5D%5B0%5D=Beef&refinementList%5Bcategory1NI%5D%5B1%5D=Lamb`, 'beef-lamb'),
    source(name, `${root}/meat-poultry-and-seafood/chicken--poultry?pg=1`, 'chicken'),
    source(name, `${root}/meat-poultry-and-seafood/pork--ham?pg=1`, 'pork'),
    source(name, `${root}/meat-poultry-and-seafood/mince-sausages--meatballs?pg=1`, 'sausages'),
    source(name, `${root}/meat-poultry-and-seafood/seafood?pg=1`, 'seafood'),
    source(name, `${root}/fridge-deli-and-eggs/eggs?pg=1`, 'eggs'),
    source(name, `${root}/fridge-deli-and-eggs/butter--margarine?pg=1`, 'butter'),
    source(name, `${root}/fridge-deli-and-eggs/cheese?pg=1`, 'cheese'),
    source(name, `${root}/fridge-deli-and-eggs/cream-custard--desserts?pg=1`, 'cream'),
    source(name, `${root}/fridge-deli-and-eggs/yoghurt?pg=1`, 'yoghurt'),
    source(name, `${root}/fruit-and-vegetables/vegetables?pg=1`, 'fresh-vegetables'),
    source(name, `${root}/pantry/oil--vinegar?pg=1`, 'oils-vinegars'),
    source(name, `${root}/pantry/bulk-foods?pg=1`, 'nuts-bulk-mix'),
  ];
}

function source(name, url, category) {
  return { name, url, category };
}

function readCatalogue() {
  try {
    const decoded = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
    return {
      updatedAt: decoded.updatedAt || null,
      products: Array.isArray(decoded.products) ? decoded.products : [],
      location: decoded.location || LOCATION,
    };
  } catch (_) {
    return { updatedAt: null, products: [], location: LOCATION };
  }
}

function writeCatalogue(catalogue) {
  const temporaryPath = `${DATA_PATH}.tmp`;
  fs.writeFileSync(temporaryPath, JSON.stringify(catalogue, null, 2));
  fs.renameSync(temporaryPath, DATA_PATH);
}

function getGroceryCatalogue() {
  const catalogue = readCatalogue();
  return {
    ...catalogue,
    status: { ...state },
  };
}

function startGroceryScrape() {
  if (activeScrape) return activeScrape;
  activeScrape = scrapeGroceryCatalogue().finally(() => {
    activeScrape = null;
  });
  return activeScrape;
}

async function scrapeGroceryCatalogue() {
  const { chromium, firefox } = require('playwright');
  const headless = process.env.GROCERY_HEADLESS !== 'false';

  Object.assign(state, {
    running: true,
    startedAt: new Date().toISOString(),
    completedAt: null,
    error: null,
    pagesCompleted: 0,
    pagesTotal: grocerySources.length,
    stores: {},
    warning: null,
  });

  const chromiumBrowser = await chromium.launch({
    headless,
    args: ['--disable-http2'],
  });
  const firefoxBrowser = await firefox.launch({ headless });
  const contexts = [];
  const results = [];

  try {
    const storeContexts = await createBlenheimStoreContexts({
      chromiumBrowser,
      firefoxBrowser,
    });
    contexts.push(...Object.values(storeContexts).filter(Boolean));

    let nextIndex = 0;
    const workers = Array.from(
      { length: MAX_PARALLEL_PAGES },
      async () => {
        while (nextIndex < grocerySources.length) {
          const index = nextIndex;
          nextIndex += 1;
          const sourceItem = grocerySources[index];
          try {
            const context = contextForSource(storeContexts, sourceItem);
            if (!context) {
              throw new Error(
                `${sourceItem.name} did not confirm a Blenheim store.`,
              );
            }
            results.push(...await scrapeGroceryPage(context, sourceItem));
          } catch (error) {
            console.error(
              `Grocery scrape failed for ${sourceItem.url}:`,
              error.message,
            );
          } finally {
            state.pagesCompleted += 1;
          }
        }
      },
    );
    await Promise.all(workers);

    if (results.length === 0) {
      throw new Error(
        'No prices were collected from a confirmed Blenheim store.',
      );
    }
    const catalogue = mergePriceHistory(readCatalogue(), results);
    writeCatalogue(catalogue);
    state.completedAt = catalogue.updatedAt;
    const unavailableStores = Object.entries(state.stores)
      .filter(([, value]) => !value.ready)
      .map(([name, value]) => `${name}: ${value.error}`);
    state.warning = unavailableStores.length > 0
      ? `Some Blenheim stores were unavailable. ${unavailableStores.join(' ')}`
      : null;
    return catalogue;
  } catch (error) {
    state.error = error && error.message ? error.message : String(error);
    throw error;
  } finally {
    state.running = false;
    await Promise.all(contexts.map((context) => context.close()));
    await Promise.all([
      chromiumBrowser.close(),
      firefoxBrowser.close(),
    ]);
  }
}

async function createBlenheimStoreContexts({
  chromiumBrowser,
  firefoxBrowser,
}) {
  const contextOptions = {
    geolocation: {
      latitude: LOCATION.latitude,
      longitude: LOCATION.longitude,
    },
    permissions: ['geolocation'],
  };
  const contexts = {
    Woolworths: await firefoxBrowser.newContext(contextOptions),
    'PAK\'nSAVE': await chromiumBrowser.newContext(contextOptions),
    'New World': await chromiumBrowser.newContext(contextOptions),
  };

  await Promise.all(
    Object.entries(contexts).map(async ([name, context]) => {
      try {
        const selectedStore = name === 'Woolworths'
          ? await selectWoolworthsBlenheim(context)
          : await selectFoodstuffsBlenheim(context, name);
        state.stores[name] = { ready: true, selectedStore };
        console.log(`${name} grocery prices linked to ${selectedStore}.`);
      } catch (error) {
        const message = error && error.message
          ? error.message
          : String(error);
        state.stores[name] = { ready: false, error: message };
        await context.close();
        contexts[name] = null;
        console.error(`${name} Blenheim setup failed: ${message}`);
      }
    }),
  );

  if (!Object.values(contexts).some(Boolean)) {
    throw new Error('No supermarket confirmed a Blenheim store.');
  }
  return contexts;
}

async function selectWoolworthsBlenheim(context) {
  const page = await context.newPage();
  await blockHeavyResources(page);
  try {
    await page.goto('https://www.woolworths.co.nz/bookatimeslot', {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });
    const changeButton = page.locator('fieldset div div p button').first();
    await changeButton.waitFor({ timeout: 20000 });
    await changeButton.click();
    const locationInput = page.locator(
      'form-suburb-autocomplete form-input input',
    );
    await locationInput.waitFor({ timeout: 15000 });
    const saveButton = page.getByText(
      'Save and Continue Shopping',
      { exact: false },
    );
    const searches = [
      'Blenheim',
      'Blenheim 7201',
      '51 Arthur Street, Blenheim',
    ];
    let selected = false;
    for (const search of searches) {
      await locationInput.fill('');
      await locationInput.type(search, { delay: 80 });
      await page.waitForTimeout(2000);
      const suggestion = page.locator('form-suburb-autocomplete').getByText(
        /Blenheim/i,
      ).last();
      if (await suggestion.count() > 0) {
        await suggestion.click();
      } else {
        await page.keyboard.press('ArrowDown');
        await page.keyboard.press('Enter');
      }
      await page.waitForTimeout(700);
      if (await saveButton.isEnabled()) {
        selected = true;
        break;
      }
    }
    if (!selected) {
      throw new Error(
        'Woolworths did not offer a selectable Blenheim address.',
      );
    }
    await saveButton.click();
    await page.waitForTimeout(2500);

    const bodyText = clean(await page.locator('body').innerText());
    if (!/\bBlenheim\b/i.test(bodyText)) {
      throw new Error('Woolworths did not confirm Blenheim after selection.');
    }
    return 'Woolworths Blenheim';
  } finally {
    await page.close();
  }
}

async function selectFoodstuffsBlenheim(context, name) {
  const page = await context.newPage();
  await blockHeavyResources(page);
  try {
    const host = name === 'PAK\'nSAVE'
      ? 'https://www.paknsave.co.nz/'
      : 'https://www.newworld.co.nz/';
    for (let attempt = 1; attempt <= 4; attempt += 1) {
      await page.goto(host, {
        waitUntil: 'domcontentloaded',
        timeout: 45000,
      });
      await page.waitForTimeout(5000);
      await page.waitForSelector('div.ds-mx-auto', { timeout: 20000 });
      const bodyText = clean(await page.locator('body').innerText());
      if (/\bBlenheim\b/i.test(bodyText)) {
        return `${name} Blenheim`;
      }
      if (attempt < 4) {
        await context.clearCookies();
        await page.waitForTimeout(2000);
      }
    }
    throw new Error(`${name} selected a store outside Blenheim.`);
  } finally {
    await page.close();
  }
}

function contextForSource(contexts, sourceItem) {
  return contexts[sourceItem.name] || null;
}

async function scrapeGroceryPage(context, sourceItem) {
  const page = await context.newPage();
  await blockHeavyResources(page);

  try {
    await page.goto(sourceItem.url, {
      waitUntil: 'domcontentloaded',
      timeout: 30000,
    });
    for (let index = 0; index < 5; index += 1) {
      await page.keyboard.press('PageDown');
      await page.waitForTimeout(350);
    }
    await page.waitForTimeout(1000);

    if (sourceItem.url.includes('woolworths.co.nz')) {
      return await scrapeWoolworthsPage(page, sourceItem);
    }
    return await scrapeFoodstuffsPage(page, sourceItem);
  } finally {
    await page.close();
  }
}

async function scrapeWoolworthsPage(page, sourceItem) {
  await page.waitForSelector('div.product-entry', { timeout: 12000 });
  const rawProducts = await page.$$eval(
    'div.product-entry',
    (elements) => elements.map((element) => {
      const cleanText = (value) =>
        String(value || '').replace(/\s+/g, ' ').trim();
      const title = element.querySelector('h3[id*="-title"]');
      const titleId = title?.getAttribute('id') || '';
      const nameAndSize = cleanText(title?.textContent);
      const priceNode = element.querySelector('product-price h3');
      const href = element.querySelector('a[href]')?.href || '';
      return {
        id: titleId.replace(/\D/g, ''),
        nameAndSize,
        priceText: cleanText(priceNode?.textContent),
        unitText: cleanText(
          element.querySelector('span.cupPrice')?.textContent,
        ),
        href,
      };
    }),
  );
  return rawProducts.map((raw) => {
    const parsed = splitNameAndSize(raw.nameAndSize);
    return buildProduct({
      id: raw.id,
      name: parsed.name,
      size: parsed.size,
      price: parsePrice(raw.priceText),
      unitPrice: normaliseUnitPrice(raw.unitText),
      sourceSite: 'countdown.co.nz',
      sourceUrl: raw.href,
      category: sourceItem.category,
    });
  }).filter(Boolean);
}

async function scrapeFoodstuffsPage(page, sourceItem) {
  await page.waitForSelector(
    'div[data-testid*="-EA-000"], div[data-testid*="-KGM-000"]',
    { timeout: 12000 },
  );
  const rawProducts = await page.$$eval(
    'div[data-testid*="-EA-000"], div[data-testid*="-KGM-000"]',
    (elements) => elements.map((element) => {
      const cleanText = (value) =>
        String(value || '').replace(/\s+/g, ' ').trim();
      const name = cleanText(
        element.querySelector('p[data-testid="product-title"]')?.textContent,
      );
      let size = cleanText(
        element.querySelector('p[data-testid="product-subtitle"]')?.textContent,
      );
      if (size === 'kg') size = 'per kg';
      const dollars = cleanText(
        element.querySelector('p[data-testid="price-dollars"]')?.textContent,
      );
      const cents = cleanText(
        element.querySelector('p[data-testid="price-cents"]')?.textContent,
      );
      const price = Number(`${dollars || 0}.${(cents || '00').replace(/\D/g, '')}`);
      const unitText = Array.from(element.querySelectorAll('p'))
        .map((node) => cleanText(node.textContent))
        .reverse()
        .find((text) => /\$\d+(?:\.\d+)?\s*\/\s*\w+/i.test(text)) || '';
      const testId = element.getAttribute('data-testid') || '';
      const href = element.querySelector('a[href]')?.href || '';
      return { name, size, price, unitText, testId, href };
    }),
  );
  const isPaknsave = sourceItem.url.includes('paknsave');
  return rawProducts.map((raw) => buildProduct({
    id: `${isPaknsave ? 'P' : 'N'}${
      raw.testId.split(/-(?:EA|KGM)-000/)[0]
    }`,
    name: raw.name,
    size: raw.size,
    price: raw.price,
    unitPrice: normaliseUnitPrice(raw.unitText),
    sourceSite: isPaknsave ? 'paknsave.co.nz' : 'newworld.co.nz',
    sourceUrl: raw.href,
    category: sourceItem.category,
  })).filter(Boolean);
}

function mergePriceHistory(existingCatalogue, scrapedProducts) {
  const byKey = new Map(
    existingCatalogue.products.map((product) => [
      `${product.sourceSite}:${product.id}`,
      product,
    ]),
  );
  const today = new Date().toISOString().slice(0, 10);

  for (const scraped of scrapedProducts) {
    const key = `${scraped.sourceSite}:${scraped.id}`;
    const existing = byKey.get(key);
    if (!existing) {
      byKey.set(key, {
        ...scraped,
        lastChecked: today,
        priceHistory: [{ date: today, price: scraped.currentPrice }],
      });
      continue;
    }

    const history = Array.isArray(existing.priceHistory)
      ? [...existing.priceHistory]
      : [];
    const last = history[history.length - 1];
    if (
      (!last || Math.abs(Number(last.price) - scraped.currentPrice) > 0.01) &&
      last?.date !== today
    ) {
      history.push({ date: today, price: scraped.currentPrice });
    }
    byKey.set(key, {
      ...existing,
      ...scraped,
      lastChecked: today,
      priceHistory: history,
    });
  }

  return {
    updatedAt: new Date().toISOString(),
    location: LOCATION,
    products: [...byKey.values()],
  };
}

function buildProduct(product) {
  if (
    !product.id ||
    !product.name ||
    !Number.isFinite(product.price) ||
    product.price <= 0 ||
    product.price > 999
  ) {
    return null;
  }
  return {
    id: product.id,
    name: product.name,
    size: product.size || '',
    sourceSite: product.sourceSite,
    sourceUrl: product.sourceUrl || '',
    category: product.category,
    currentPrice: product.price,
    unitPrice: product.unitPrice || deriveUnitPrice(
      product.size,
      product.price,
    ),
  };
}

function deriveUnitPrice(size, price) {
  const match = String(size || '').toLowerCase().match(
    /(\d+(?:\.\d+)?)\s*(kg|g|l|ml)\b/,
  );
  if (!match) return size === 'per kg' ? `${price}/kg` : '';
  let quantity = Number(match[1]);
  let unit = match[2];
  if (unit === 'g') {
    quantity /= 1000;
    unit = 'kg';
  } else if (unit === 'ml') {
    quantity /= 1000;
    unit = 'L';
  } else if (unit === 'l') {
    unit = 'L';
  }
  return quantity > 0 ? `${round(price / quantity)}/${unit}` : '';
}

function normaliseUnitPrice(value) {
  const match = String(value || '').match(
    /\$?\s*(\d+(?:\.\d+)?)\s*\/\s*(?:(\d+)\s*)?(kg|g|l|ml|ea|each)/i,
  );
  if (!match) return '';
  let price = Number(match[1]);
  const amount = Number(match[2] || 1);
  let unit = match[3].toLowerCase();
  if (unit === 'g') {
    price *= 1000 / amount;
    unit = 'kg';
  } else if (unit === 'ml') {
    price *= 1000 / amount;
    unit = 'L';
  } else {
    price /= amount;
    if (unit === 'l') unit = 'L';
  }
  return `${round(price)}/${unit}`;
}

function splitNameAndSize(value) {
  const text = clean(value);
  const match = text.match(
    /\b(?:tray\s*)?\d+(?:\.\d+)?(?:-\d+(?:\.\d+)?)?\s*(?:kg|g|l|ml|pack)\b/i,
  );
  if (!match) return { name: text, size: '' };
  return {
    name: clean(text.slice(0, match.index)),
    size: clean(match[0]).replace(/l\b/i, 'L'),
  };
}

function round(value) {
  return Math.round(value * 100) / 100;
}

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function parsePrice(value) {
  const match = String(value || '').replace(/,/g, '').match(/\d+(?:\.\d{1,2})?/);
  return match ? Number(match[0]) : 0;
}

async function blockHeavyResources(page) {
  await page.route('**/*', async (route) => {
    const request = route.request();
    if (['image', 'font', 'media'].includes(request.resourceType())) {
      await route.abort();
      return;
    }
    await route.continue();
  });
}

function scheduleGroceryScrapes() {
  setInterval(() => {
    startGroceryScrape().catch((error) => {
      console.error('Scheduled grocery scrape failed:', error);
    });
  }, SCRAPE_INTERVAL_MS).unref();
}

module.exports = {
  LOCATION,
  deriveUnitPrice,
  getGroceryCatalogue,
  mergePriceHistory,
  normaliseUnitPrice,
  scheduleGroceryScrapes,
  splitNameAndSize,
  startGroceryScrape,
};

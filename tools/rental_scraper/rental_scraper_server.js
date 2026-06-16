const http = require('http');

const PORT = Number(process.env.RENTAL_SCRAPER_PORT || 51247);
const MAX_BODY = 1024 * 1024;
const PARSER_VERSION = 6;
const MAX_PARALLEL_SOURCES = 4;

function send(res, code, body) {
  res.writeHead(code, {
    'Access-Control-Allow-Headers': 'Content-Type, X-Requested-With',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Private-Network': 'true',
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8',
  });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > MAX_BODY) {
        reject(new Error('Request body is too large.'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function requirePlaywright() {
  try {
    return require('playwright');
  } catch (_) {
    throw new Error(
      'Playwright is not installed. Run: cd tools/rental_scraper && npm install && npm run install-browser',
    );
  }
}

async function scrapeSources(sources) {
  const { chromium } = requirePlaywright();
  const browser = await chromium.launch({ headless: true });

  try {
    return await scrapeWithLimit(sources, MAX_PARALLEL_SOURCES, (source) =>
      scrapeSource(browser, source),
    );
  } finally {
    await browser.close();
  }
}

async function scrapeJobSources(sources) {
  const { chromium } = requirePlaywright();
  const browser = await chromium.launch({ headless: true });

  try {
    return await scrapeWithLimit(sources, MAX_PARALLEL_SOURCES, (source) =>
      scrapeJobSource(browser, source),
    );
  } finally {
    await browser.close();
  }
}

async function scrapeWithLimit(sources, limit, scrape) {
  const results = new Array(sources.length);
  let nextIndex = 0;
  const workers = Array.from({
    length: Math.min(limit, sources.length),
  }, async () => {
    while (nextIndex < sources.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await scrape(sources[index]);
    }
  });

  await Promise.all(workers);
  return results;
}

async function scrapeSource(browser, source) {
  const page = await browser.newPage({
    userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  });

  try {
    await routePlaywrightExclusions(page);
    await page.goto(source.url, {
      waitUntil: 'domcontentloaded',
      timeout: 45000,
    });
    await page.waitForTimeout(2500);
    await settlePage(page);

    const rawListings = await page.evaluate((sourceUrl) => {
      const clean = (value) => String(value || '').replace(/\s+/g, ' ').trim();
      const absolute = (href) => {
        try {
          return new URL(href, location.href).toString();
        } catch (_) {
          return '';
        }
      };
      const listingWords =
        /(rent|rental|property|listing|residential|house|unit|apartment)/i;
      const marlboroughHousingWords =
        /(marlborough|blenheim|renwick|picton|seddon|havelock|springlands|redwoodtown|mayfield|witherlea|riverlands|rapaura|grovetown|riversdale|burleigh|islington|omaka)/i;
      const excludedHousingWords =
        /(auckland|wairau[-\s]+valley|archers[-\s]+road|north[-\s]+shore|takapuna|glenfield|albany|manukau|waitakere)/i;
      const priceWords = /\$\s?\d[\d,]*(?:\s?(?:pw|p\/w|per week|weekly|\/week))?/i;
      const anchors = Array.from(document.querySelectorAll('a[href]'));
      const links = anchors
        .map((anchor) => ({
          href: absolute(anchor.getAttribute('href')),
          text: clean(anchor.innerText || anchor.textContent),
        }))
        .filter(
          (item) =>
            item.href &&
            listingWords.test(item.href) &&
            marlboroughHousingWords.test(
              `${sourceUrl} ${item.href} ${item.text}`,
            ) &&
            !excludedHousingWords.test(`${item.href} ${item.text}`),
        );
      const nodes = Array.from(document.querySelectorAll('article, li, div, a'));
      const snippets = [];

      for (const node of nodes) {
        const text = clean(node.innerText || node.textContent);
        if (text.length < 25 || text.length > 1400) continue;
        if (!priceWords.test(text)) continue;

        const link =
          node.href ||
          node.querySelector?.('a[href]')?.href ||
          links.find((item) => text.includes(item.text) && item.text)?.href ||
          '';
        if (
          !marlboroughHousingWords.test(
            `${sourceUrl} ${text} ${absolute(link)}`,
          ) ||
          excludedHousingWords.test(`${text} ${absolute(link)}`)
        ) {
          continue;
        }
        snippets.push({ text, link: absolute(link) });
      }

      return { links, snippets };
    });

    const listings = parseListings(source, rawListings);
    return {
      sourceName: source.name,
      listings,
      error: null,
    };
  } catch (error) {
    return {
      sourceName: source.name,
      listings: [],
      error: error && error.message ? error.message : String(error),
    };
  } finally {
    await page.close();
  }
}

async function scrapeJobSource(browser, source) {
  const page = await browser.newPage({
    userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  });

  try {
    await routePlaywrightExclusions(page);
    await page.goto(source.url, {
      waitUntil: 'domcontentloaded',
      timeout: 18000,
    });
    await page.waitForTimeout(1000);
    await settlePage(page, 2, 500);

    const rawListings = await page.evaluate((sourceUrl) => {
      const clean = (value) => String(value || '').replace(/\s+/g, ' ').trim();
      const absolute = (href) => {
        try {
          return new URL(href, location.href).toString();
        } catch (_) {
          return '';
        }
      };
      const jobWords =
        /(job|jobs|career|vacanc|work|employment|seek|trademe|picknz|wine|vineyard|labour|harvest|apply)/i;
      const localJobWords = /\b(?:blenheim|renwick|picton)\b/i;
      const excludedJobLocationWords =
        /\b(?:auckland|wellington|christchurch|hamilton|tauranga|rotorua|dunedin|queenstown|nelson|richmond|motueka|timaru|ashburton|invercargill|palmerston north|new plymouth|napier|hastings|gisborne|whangarei|porirua|lower hutt|upper hutt|masterton|wanaka|westport|greymouth)\b/i;
      const localSource = localJobWords.test(sourceUrl);
      const anchors = Array.from(document.querySelectorAll('a[href]'));
      const links = anchors
        .map((anchor) => ({
          href: absolute(anchor.getAttribute('href')),
          text: clean(anchor.innerText || anchor.textContent),
        }))
        .filter(
          (item) =>
            item.href &&
            jobWords.test(`${item.href} ${item.text}`) &&
            (localSource || localJobWords.test(`${item.href} ${item.text}`)),
        );
      const nodes = Array.from(document.querySelectorAll('article, li, div, a'));
      const snippets = [];

      for (const node of nodes) {
        const text = clean(node.innerText || node.textContent);
        if (text.length < 25 || text.length > 1800) continue;
        if (!jobWords.test(text)) continue;
        const link =
          node.href ||
          node.querySelector?.('a[href]')?.href ||
          links.find((item) => text.includes(item.text) && item.text)?.href ||
          '';
        if (
          !(localSource || localJobWords.test(`${text} ${absolute(link)}`)) ||
          excludedJobLocationWords.test(text)
        ) {
          continue;
        }

        const title =
          clean(
            node.querySelector?.(
              'h1, h2, h3, [data-automation*="title"], [data-testid*="title"], [class*="title"]',
            )?.innerText,
          ) ||
          clean(node.getAttribute?.('aria-label')) ||
          clean(node.getAttribute?.('title')) ||
          clean(
            node.querySelector?.('a[href]')?.innerText ||
              node.querySelector?.('a[href]')?.textContent,
          );

        snippets.push({ text, link: absolute(link), title });
      }

      return { links, snippets };
    }, source.url);

    const listings = parseJobListings(source, rawListings);
    return {
      sourceName: source.name,
      listings,
      error: null,
    };
  } catch (error) {
    return {
      sourceName: source.name,
      listings: [],
      error: error && error.message ? error.message : String(error),
    };
  } finally {
    await page.close();
  }
}

async function routePlaywrightExclusions(page) {
  await page.route('**/*', async (route) => {
    const request = route.request();
    const resourceType = request.resourceType();

    if (
      resourceType === 'image' ||
      resourceType === 'font' ||
      resourceType === 'media'
    ) {
      await route.abort();
      return;
    }

    await route.continue();
  });
}

async function settlePage(page, passes = 4, delayMs = 700) {
  for (let index = 0; index < passes; index += 1) {
    await page.mouse.wheel(0, 1800);
    await page.waitForTimeout(delayMs);
  }
  await page.mouse.wheel(0, -7200);
  await page.waitForTimeout(delayMs);
}

function parseListings(source, raw) {
  const seen = new Set();
  const listings = [];
  const snippets = raw.snippets || [];
  const links = raw.links || [];
  const count = Math.max(snippets.length, links.length);

  for (let index = 0; index < count && listings.length < 40; index += 1) {
    const snippet = snippets[index] || {};
    const link = snippet.link || links[index]?.href || source.url;
    const text = snippet.text || links[index]?.text || source.name;
    if (hasExcludedHousingLocationEvidence(`${text} ${link} ${source.url}`)) {
      continue;
    }
    if (!hasMarlboroughHousingEvidence(`${text} ${link} ${source.url}`)) {
      continue;
    }
    const listing = listingFromText(source, text, link);
    const key = `${listing.address}|${listing.price}`.toLowerCase();
    if (seen.has(key)) {
      const existing = listings.find(
        (item) =>
          `${item.address}|${item.price}`.toLowerCase() === key &&
          item.source === source.url &&
          listing.source !== source.url,
      );
      if (existing) existing.source = listing.source;
      continue;
    }
    seen.add(key);
    listings.push(listing);
  }

  return listings;
}

function parseJobListings(source, raw) {
  const seen = new Set();
  const listings = [];
  const snippets = raw.snippets || [];
  const links = raw.links || [];
  const count = Math.max(snippets.length, links.length);

  for (let index = 0; index < count && listings.length < 50; index += 1) {
    const snippet = snippets[index] || {};
    const link = snippet.link || links[index]?.href || source.url;
    const text = snippet.text || links[index]?.text || source.name;
    if (!isJobDetailUrl(link)) continue;
    if (!hasAllowedLocalJobEvidence(`${text} ${link} ${source.url}`)) continue;
    if (hasExcludedJobLocationEvidence(text)) continue;
    const titleCandidate = snippet.title || links[index]?.text || '';
    const listing = jobListingFromText(source, text, link, titleCandidate);
    if (!isAllowedLocalJob(listing, source.url)) continue;
    if (listing.title === 'Job title not found') continue;
    if (!looksLikeRealJobListing(listing)) continue;
    if (looksLikeSearchCriteria(listing)) continue;

    const key = `${listing.title}|${listing.employer}|${listing.source}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    listings.push(listing);
  }

  return listings;
}

function jobListingFromText(source, text, link, titleCandidate = '') {
  const title = jobTitle(text, link, titleCandidate);
  const employer = jobEmployer(source.name, text, title);
  return {
    title,
    employer,
    type: jobType(text),
    area: jobArea(`${text} ${source.url}`),
    contact: contactText(text),
    posted: postedAge(text),
    quickApply: hasQuickApply(text),
    source: link,
    notes: jobDescription(text, title, employer),
  };
}

function listingFromText(source, text, link) {
  return {
    address: cleanAddress(match(text, /\b\d+[A-Za-z]?(?:\/\d+[A-Za-z]?)?\s+[^|]{2,90}\b(?:street|st|road|rd|avenue|ave|drive|dr|lane|ln|place|pl|court|ct|crescent|cres|terrace|tce|way)\b[^|,]{0,45}/i)) ||
      cleanAddress(match(text, /\b(?:Blenheim|Picton|Renwick|Springlands|Redwoodtown|Mayfield|Marlborough)\b[^$]{0,80}/i)) ||
      'Address not found',
    price:
      match(text, /\$\s?\d[\d,]*(?:\s?(?:pw|p\/w|per week|weekly|\/week))?/i) ||
      'Price not found',
    size: sizeText(text),
    agency: agencyText(source.name, text),
    contact: contactText(text),
    source: link,
    notes: text,
  };
}

function sizeText(text) {
  const values = [
    match(text, /\b\d+\s?(?:bed|beds|bedroom|bedrooms|brm|bdrm)\b/i),
    match(text, /\b\d+\s?(?:bath|baths|bathroom|bathrooms)\b/i),
    match(text, /\b\d+\s?(?:m2|sqm|square metres)\b/i),
  ].filter(Boolean);
  if (values.length) return values.join(', ');

  const beforePrice = String(text || '')
    .replace(/\$\s?\d[\d,]*(?:\s?(?:pw|p\/w|per week|weekly|\/week))?.*/i, '')
    .trim();
  const rooms = beforePrice.match(/(?:Now|Available:[^$]*?)\s(\d)\s+(\d)(?:\s+(\d))?\s*$/i);

  if (!rooms) return 'Size not found';

  return [
    `${rooms[1]} bed`,
    `${rooms[2]} bath`,
    rooms[3] ? `${rooms[3]} parking` : '',
  ]
    .filter(Boolean)
    .join(', ');
}

function agencyText(sourceName, text) {
  const agencies = [
    'Trade Me',
    'realestate.co.nz',
    'OneRoof',
    'Harcourts',
    'Bayleys',
    'Ray White',
    'Summit',
    'First National',
    'Property Brokers',
    'Professionals',
    'Quinovic',
    'Marlborough Property Management',
  ];

  for (const agency of agencies) {
    if (text.toLowerCase().includes(agency.toLowerCase())) return agency;
  }

  return sourceName;
}

function contactText(text) {
  const phone = match(text, /(?:\+64|0)\s?\d{1,3}[\s-]?\d{3}[\s-]?\d{3,4}/);
  const email = match(text, /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
  if (phone && email) return `${phone} / ${email}`;
  return phone || email || agentName(text) || 'Contact not found';
}

function postedAge(text) {
  return (
    match(
      text,
      /\b(?:listed|posted)\s+(?:just now|today|yesterday|\d+\s*(?:m|minute|minutes|h|hour|hours|d|day|days)\s+ago)\b/i,
    ) ||
    match(
      text,
      /\b(?:just now|today|yesterday|\d+\s*(?:m|minute|minutes|h|hour|hours|d|day|days)\s+ago)\b/i,
    ) ||
    'Posted date not found'
  );
}

function hasQuickApply(text) {
  return /\b(?:quick apply|easily apply|apply with seek)\b/i.test(
    String(text || ''),
  );
}

function match(text, pattern) {
  const result = String(text || '').match(pattern);
  return result ? result[0].replace(/\s+/g, ' ').trim() : null;
}

function cleanAddress(value) {
  if (!value) return null;
  return value
    .replace(/^(?:Listed\s+)?(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),?\s*)?\d{1,2}\s+[A-Za-z]{3}\s+/i, '')
    .replace(/^Today\s+/i, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function agentName(text) {
  const result = String(text || '').match(/^([A-Z][a-z]+(?:\s+[A-Z][a-z'-]+){1,3})\s+Listed\b/);
  return result ? result[1].trim() : null;
}

function jobTitle(text, link = '', titleCandidate = '') {
  const lines = jobLines(text);
  const badWords =
    /(apply|save|listed|classification|subclassification|location|salary|source|seek|trademe|indeed|picknz|backpacker|job search|view all)/i;
  const titleWords =
    /(worker|labourer|operator|assistant|driver|cleaner|chef|hand|manager|administrator|technician|cellar|vineyard|harvest|picker|packer|receptionist|coordinator|supervisor|retail|sales|support|caregiver|mechanic|builder|electrician)/i;
  const titleLine = lines.find(
    (line) =>
      line.length >= 4 &&
      line.length <= 95 &&
      !badWords.test(line) &&
      (titleWords.test(line) || looksLikeTitle(line)),
  );
  const candidateTitle = cleanJobTitle(titleCandidate, badWords);
  if (candidateTitle) return candidateTitle;
  if (titleLine) return titleLine;

  const matched = match(
    text,
    /\b[A-Z][A-Za-z/&,\-\s]{3,70}(?:worker|labourer|operator|assistant|driver|cleaner|chef|hand|manager|administrator|technician|picker|packer|supervisor|receptionist|coordinator)\b/i,
  );
  if (matched) return matched;

  return titleFromUrl(link) || titleFromFirstUsefulLine(lines) || 'Job title not found';
}

function jobEmployer(sourceName, text, title) {
  const labelled = String(text || '').match(/(?:company|employer|business|agency)[:\s]+([^\n\r|]+)/i);
  if (labelled) return cleanJobLine(labelled[1]);

  const atEmployer = String(text || '').match(/\bat\s+([A-Z][A-Za-z0-9 '&.-]{2,70})/);
  if (atEmployer) return cleanJobLine(atEmployer[1]);

  const lines = jobLines(text);
  const candidate = lines.find((line) =>
    /\b(ltd|limited|estate|vineyard|wines|winery|group|recruitment|staff|company|services)\b/i.test(line) &&
    line.length <= 90 &&
    line.toLowerCase() !== String(title || '').toLowerCase()
  );
  return candidate || sourceName;
}

function jobDescription(text, title, employer) {
  const titleLower = String(title || '').toLowerCase();
  const employerLower = String(employer || '').toLowerCase();
  const badWords =
    /^(apply|save|listed|classification|subclassification|location|salary|source|seek|trademe|indeed|picknz|backpacker|job search|view all)\b/i;
  const lines = jobLines(text).filter((line) => {
    const lower = line.toLowerCase();
    if (lower === titleLower || lower === employerLower) return false;
    if (badWords.test(line)) return false;
    if (/^https?:\/\//i.test(line)) return false;
    if (line.length < 18 || line.length > 220) return false;
    return true;
  });

  const description = uniqueLines(lines).slice(0, 4).join(' ');
  return description || cleanJobNotes(text).slice(0, 360);
}

function jobType(text) {
  const lower = String(text || '').toLowerCase();
  const groups = [
    ['Wine', ['wine', 'vineyard', 'viticulture', 'cellar', 'harvest', 'pruning', 'winery', 'grape']],
    ['Labour', ['labour', 'labourer', 'factory', 'warehouse', 'process worker', 'seasonal', 'picker', 'packer']],
    ['Hospitality', ['hospitality', 'cafe', 'restaurant', 'barista', 'kitchen', 'chef', 'front of house']],
    ['Retail', ['retail', 'sales assistant', 'customer service', 'checkout']],
    ['Care', ['support worker', 'caregiver', 'healthcare', 'disability', 'aged care']],
    ['Admin', ['admin', 'administrator', 'reception', 'office']],
    ['Trades', ['builder', 'plumber', 'electrician', 'mechanic', 'trade']],
    ['Transport', ['driver', 'courier', 'truck', 'forklift', 'delivery']],
    ['Cleaning', ['cleaner', 'cleaning', 'housekeeping']],
  ];

  for (const [type, keywords] of groups) {
    if (keywords.some((keyword) => lower.includes(keyword))) return type;
  }

  return 'Other';
}

function jobArea(text) {
  const lower = String(text || '').toLowerCase();
  if (lower.includes('renwick')) return 'Renwick';
  if (lower.includes('picton')) return 'Picton';
  if (lower.includes('blenheim')) return 'Blenheim';
  return 'Local area to confirm';
}

function isAllowedLocalJob(listing, sourceUrl = '') {
  const text = `${listing.title} ${listing.notes} ${sourceUrl}`;
  return (
    hasAllowedLocalJobEvidence(text) && !hasExcludedJobLocationEvidence(text)
  );
}

function hasAllowedLocalJobEvidence(text) {
  return /\b(?:blenheim|renwick|picton)\b/i.test(String(text || ''));
}

function hasExcludedJobLocationEvidence(text) {
  return /\b(?:auckland|wellington|christchurch|hamilton|tauranga|rotorua|dunedin|queenstown|nelson|richmond|motueka|timaru|ashburton|invercargill|palmerston north|new plymouth|napier|hastings|gisborne|whangarei|porirua|lower hutt|upper hutt|masterton|wanaka|westport|greymouth)\b/i.test(
    String(text || ''),
  );
}

function isJobDetailUrl(url) {
  const lower = String(url || '').toLowerCase();
  if (!lower || lower === 'about:blank') return false;
  if (looksLikeSearchUrl(lower)) return false;

  return (
    /seek\.co\.nz\/job\/\d+/.test(lower) ||
    /trademe\.co\.nz\/a\/jobs\/.+\/listing\/\d+/.test(lower) ||
    /indeed\.com\/(?:viewjob|rc\/clk|pagead\/clk)/.test(lower) ||
    /winejobsonline\.com\/(?:jobs|job)\/[^/?#]+/.test(lower) ||
    /picknz\.co\.nz\/(?:jobs|job)\/[^/?#]+/.test(lower) ||
    /backpackerboard\.co\.nz\/work_jobs\/.+job/.test(lower) ||
    /\b(?:job|jobs|listing|vacancy|career|position)[-/][^/?#]+/.test(lower)
  );
}

function looksLikeSearchUrl(url) {
  const lower = String(url || '').toLowerCase();
  return (
    lower.includes('/jobs?') ||
    lower.includes('/jobs/in-') ||
    lower.includes('/jobs-in-') ||
    lower.includes('/jobs/search') ||
    /-jobs\/in-/.test(lower) ||
    lower.includes('search_string=') ||
    lower.includes('?q=') ||
    lower.includes('&q=') ||
    lower.includes('?l=') ||
    lower.includes('&l=') ||
    lower.endsWith('/jobs') ||
    lower.endsWith('/jobs/')
  );
}

function looksLikeSearchCriteria(listing) {
  const text = `${listing.title} ${listing.employer} ${listing.notes}`.toLowerCase();
  return (
    /classification.*subclassification/.test(text) ||
    /accounting.*administration.*advertising.*banking/.test(text) ||
    /all marlborough/.test(text) ||
    /job title not found/.test(text)
  );
}

function looksLikeRealJobListing(listing) {
  const title = String(listing.title || '').trim();
  const lowerTitle = title.toLowerCase();
  const source = String(listing.source || '').toLowerCase();

  if (/^\$/.test(title)) return false;
  if (/^(show date|refine|refine your search|people search|career advice|companies|recruiters)$/i.test(title)) {
    return false;
  }
  if (/^(last \d+ days|annually|full time|part time|casual\/vacation|contract\/temp)$/i.test(title)) {
    return false;
  }
  if (lowerTitle === 'this is a' || lowerTitle.includes('in blenheim marlborough')) {
    return false;
  }
  if (/seek\.com\/job\/\d+/.test(source)) return true;
  if (/trademe\.co\.nz\/a\/jobs\/.+\/listing\/\d+/.test(source)) return true;

  return !looksLikeSearchUrl(source);
}

function cleanJobTitle(value, badWords) {
  const line = cleanJobLine(value);
  if (line.length < 4 || line.length > 95) return '';
  if (badWords.test(line)) return '';
  if (hasAllowedLocalJobEvidence(line) && line.split(/\s+/).length <= 2) {
    return '';
  }
  return line;
}

function titleFromFirstUsefulLine(lines) {
  const blocked =
    /(apply|save|listed|classification|subclassification|location|salary|source|seek|trademe|indeed|picknz|backpacker|job search|view all|blenheim|renwick|picton)/i;
  return (
    lines.find(
      (line) =>
        line.length >= 4 &&
        line.length <= 80 &&
        !blocked.test(line) &&
        looksLikeTitle(line),
    ) || ''
  );
}

function titleFromUrl(url) {
  try {
    const parsed = new URL(url);
    const pieces = parsed.pathname
      .split('/')
      .filter(Boolean)
      .filter((piece) => !/^\d+$/.test(piece))
      .filter((piece) => !/^(job|jobs|listing|viewjob|search)$/i.test(piece));
    const slug = pieces.pop() || '';
    const title = cleanJobLine(
      decodeURIComponent(slug)
        .replace(/\.[a-z0-9]+$/i, '')
        .replace(/[-_+]+/g, ' '),
    );
    if (title.length >= 4 && title.length <= 95) return title;
  } catch (_) {
    return '';
  }
  return '';
}

function hasMarlboroughHousingEvidence(text) {
  return /marlborough|blenheim|renwick|picton|seddon|havelock|springlands|redwoodtown|mayfield|witherlea|riverlands|rapaura|grovetown|riversdale|burleigh|islington|omaka/i.test(
    String(text || ''),
  );
}

function hasExcludedHousingLocationEvidence(text) {
  return /\b(?:auckland|north shore|takapuna|glenfield|albany|manukau|waitakere)\b|wairau[-\s]+valley|archers[-\s]+road/i.test(
    String(text || ''),
  );
}

function cleanJobNotes(text) {
  return asciiJobText(text)
    .replace(/\s+/g, ' ')
    .replace(/(save job|saved job|apply now|view job|view all jobs|quick apply)/gi, ' ')
    .trim();
}

function jobLines(text) {
  const sectioned = cleanJobNotes(text)
    .replace(/\b(Classification|Subclassification|Location|Salary|Listed|Posted|Job type|Company|Employer)\b/gi, '\n$1')
    .replace(/\b(Full time|Part time|Casual\/Vacation|Contract\/Temp|Temporary|Permanent)\b/g, '\n$1')
    .replace(/\s[-–]\s/g, '\n')
    .replace(/[•·]/g, '\n');
  const lines = sectioned
    .split(/\n|\||(?<=\.)\s+(?=[A-Z])/)
    .map(cleanJobLine)
    .filter((line) => line.length >= 3);

  return uniqueLines(lines);
}

function cleanJobLine(value) {
  return asciiJobText(value)
    .replace(/\s+/g, ' ')
    .replace(/^(new|featured|urgent|hiring now)\s+/i, '')
    .replace(/\b(listed|posted)\s+\d+\s*(?:d|day|days|h|hour|hours)\s+ago\b/gi, '')
    .replace(/\b(save|saved|apply now|view job|quick apply)\b/gi, '')
    .replace(/^(classification|subclassification|location|salary|job type|company|employer)[:\s-]*/i, '')
    .replace(/\s{2,}/g, ' ')
    .trim()
    .replace(/^[,;:-]+|[,;:-]+$/g, '')
    .trim();
}

function asciiJobText(value) {
  return String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201c\u201d]/g, '"')
    .replace(/[\u2013\u2014]/g, '-')
    .replace(/\u2022/g, '-')
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, '');
}

function uniqueLines(lines) {
  const seen = new Set();
  const result = [];
  for (const line of lines) {
    const key = line.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(line);
  }
  return result;
}

function looksLikeTitle(line) {
  const words = String(line || '').split(/\s+/).filter(Boolean);
  if (words.length < 2 || words.length > 10) return false;
  if (/[.!?]$/.test(line)) return false;
  return words.some((word) => /^[A-Z0-9][A-Za-z0-9/&-]*$/.test(word));
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    send(res, 204, { ok: true });
    return;
  }

  if (req.url === '/ping') {
    send(res, 200, {
      ok: true,
      parserVersion: PARSER_VERSION,
      port: PORT,
      service: 'rental_scraper',
    });
    return;
  }

  if (req.url === '/rentals' && req.method === 'POST') {
    try {
      const body = await readBody(req);
      const payload = body.trim() ? JSON.parse(body) : {};
      const sources = Array.isArray(payload.sources) ? payload.sources : [];
      const results = await scrapeSources(sources);
      send(res, 200, { ok: true, results });
    } catch (error) {
      send(res, 500, {
        ok: false,
        error: error && error.message ? error.message : String(error),
      });
    }
    return;
  }

  if (req.url === '/jobs' && req.method === 'POST') {
    try {
      const body = await readBody(req);
      const payload = body.trim() ? JSON.parse(body) : {};
      const sources = Array.isArray(payload.sources) ? payload.sources : [];
      const results = await scrapeJobSources(sources);
      send(res, 200, { ok: true, results });
    } catch (error) {
      send(res, 500, {
        ok: false,
        error: error && error.message ? error.message : String(error),
      });
    }
    return;
  }

  send(res, 404, { ok: false, error: 'Not found' });
});

if (require.main === module) {
  server.listen(PORT, '127.0.0.1', () => {
    console.log(`Rental scraper running on http://127.0.0.1:${PORT}`);
  });
}

module.exports = {
  parseJobListings,
  parseListings,
};

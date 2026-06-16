const assert = require('assert');

const { parseJobListings, parseListings } = require('./rental_scraper_server');

const rentalResults = parseListings(
  {
    name: 'Marlborough rentals',
    url: 'https://www.trademe.co.nz/a/property/residential/rent/marlborough',
  },
  {
    links: [],
    snippets: [
      {
        text:
          'Sunny 2 bedroom unit $520 per week 1 bathroom managed by Harcourts',
        link: 'https://example.test/listing/123',
      },
    ],
  },
);

assert.strictEqual(rentalResults.length, 1);
assert.strictEqual(rentalResults[0].price, '$520 per week');
assert.strictEqual(rentalResults[0].size, '2 bedroom, 1 bathroom');

const aucklandRentalResults = parseListings(
  {
    name: 'OneRoof',
    url: 'https://www.oneroof.co.nz/search/houses-for-rent/marlborough',
  },
  {
    links: [],
    snippets: [
      {
        text:
          'B 208 Archers Road Wairau Valley Auckland 2 bedroom apartment $650 per week',
        link:
          'https://www.oneroof.co.nz/property/auckland/wairau-valley/b-208-archers-road/yPWS5',
      },
    ],
  },
);

assert.strictEqual(aucklandRentalResults.length, 0);

const jobResults = parseJobListings(
  {
    name: 'Seek Blenheim',
    url: 'https://www.seek.co.nz/jobs/in-Blenheim-Marlborough',
  },
  {
    links: [],
    snippets: [
      {
        text:
          'Cellar Hand at River Wines Full time winery production and harvest support Apply now',
        link: 'https://www.seek.co.nz/job/123456',
        title: 'Cellar Hand',
      },
    ],
  },
);

assert.strictEqual(jobResults.length, 1);
assert.strictEqual(jobResults[0].title, 'Cellar Hand');
assert.strictEqual(jobResults[0].area, 'Blenheim');

const jobSearchChromeResults = parseJobListings(
  {
    name: 'Seek Blenheim',
    url: 'https://www.seek.co.nz/jobs/in-Blenheim-Marlborough',
  },
  {
    links: [],
    snippets: [
      {
        text:
          'Refine your search Show work type refinements Type Show date Blenheim',
        link: 'https://nz.seek.com/jobs/in-Blenheim-Marlborough',
        title: 'Refine your search',
      },
      {
        text:
          'Last 7 days Work in a unique port and marina environment Blenheim',
        link: 'https://nz.seek.com/jobs/in-Blenheim-Marlborough?page=2',
        title: 'Last 7 days',
      },
    ],
  },
);

assert.strictEqual(jobSearchChromeResults.length, 0);

console.log('rental_scraper_server parser tests passed');

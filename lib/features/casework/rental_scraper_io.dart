import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'rental_scraper_models.dart';

export 'rental_scraper_models.dart';

Future<List<RentalScrapeResult>> scrapeRentalSources(
  List<RentalScrapeSource> sources,
) async {
  final results = <RentalScrapeResult>[];
  for (final source in sources) {
    results.add(await _scrapeSource(source));
  }
  return results;
}

Future<List<JobScrapeResult>> scrapeJobSources(
  List<JobScrapeSource> sources,
) async {
  return [
    for (final source in sources)
      JobScrapeResult(
        sourceName: source.name,
        listings: const [],
        error: 'Automatic job scraping runs in the web app local scraper.',
      ),
  ];
}

Future<RentalScrapeResult> _scrapeSource(RentalScrapeSource source) async {
  try {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..userAgent =
          'Mozilla/5.0 (compatible; SupportWorkerLog/1.0; rental-search)';
    final request = await client.getUrl(Uri.parse(source.url));
    request.headers.set(HttpHeaders.acceptHeader, 'text/html,*/*');
    final response = await request.close().timeout(const Duration(seconds: 18));
    final html = await response.transform(utf8.decoder).join();
    client.close(force: true);

    if (response.statusCode < 200 || response.statusCode >= 400) {
      return RentalScrapeResult(
        sourceName: source.name,
        listings: const [],
        error: 'HTTP ${response.statusCode}',
      );
    }

    return RentalScrapeResult(
      sourceName: source.name,
      listings: parseRentalListings(source, html),
    );
  } on TimeoutException {
    return RentalScrapeResult(
      sourceName: source.name,
      listings: const [],
      error: 'Timed out',
    );
  } on Object catch (error) {
    return RentalScrapeResult(
      sourceName: source.name,
      listings: const [],
      error: error.toString(),
    );
  }
}

List<RentalScrapedListing> parseRentalListings(
  RentalScrapeSource source,
  String html,
) {
  return parseRentalListingsFromHtml(source, html);
}

List<RentalScrapedListing> parseRentalListingsFromHtml(
  RentalScrapeSource source,
  String html,
) {
  final plain = _decodeHtml(html)
      .replaceAll(
        RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '\n')
      .replaceAll(RegExp(r'\s+'), ' ');
  final linkMatches = RegExp(
    r'href=["'
    ']([^"'
    ']+(?:rent|rental|property|listing|residential)[^"'
    ']*)["'
    ']',
    caseSensitive: false,
  ).allMatches(html);
  final links = <String>{
    for (final match in linkMatches)
      if (_absoluteUrl(source.url, match.group(1)!) case final url?)
        if (_looksLikeListingUrl(url)) url,
  }.toList();

  final windows = _candidateWindows(plain, source.name);
  final listings = <RentalScrapedListing>[];
  final count = links.length > windows.length ? links.length : windows.length;
  for (var index = 0; index < count && listings.length < 30; index++) {
    final snippet = index < windows.length ? windows[index] : source.name;
    final link = index < links.length ? links[index] : source.url;
    if (!_hasMarlboroughHousingEvidence('$snippet $link')) continue;
    final listing = _listingFromSnippet(source, snippet, link);
    if (!_isDuplicate(listings, listing)) listings.add(listing);
  }
  return listings;
}

List<String> _candidateWindows(String plain, String sourceName) {
  final pricePattern = RegExp(
    r'\$\s?\d[\d,]*(?:\s?(?:pw|p/w|per week|weekly|/week))?',
    caseSensitive: false,
  );
  final matches = pricePattern.allMatches(plain).toList();
  return [
    for (final match in matches)
      plain.substring(
        (match.start - 220).clamp(0, plain.length),
        (match.end + 420).clamp(0, plain.length),
      ),
  ];
}

RentalScrapedListing _listingFromSnippet(
  RentalScrapeSource source,
  String snippet,
  String link,
) {
  return RentalScrapedListing(
    address: _address(snippet),
    price:
        _match(
          snippet,
          RegExp(
            r'\$\s?\d[\d,]*(?:\s?(?:pw|p/w|per week|weekly|/week))?',
            caseSensitive: false,
          ),
        ) ??
        'Price not found',
    size: _size(snippet),
    agency: _agency(source.name, snippet),
    contact: _contact(snippet),
    source: link,
    notes: snippet,
  );
}

String _address(String text) {
  final street = _match(
    text,
    RegExp(
      r'\b\d+[A-Za-z]?\s+[^|]{2,80}\b(?:street|st|road|rd|avenue|ave|drive|dr|lane|ln|place|pl|court|ct|crescent|cres|terrace|tce|way)\b[^|,]{0,40}',
      caseSensitive: false,
    ),
  );
  if (street != null) return street;
  final suburb = _match(
    text,
    RegExp(
      r'\b(?:Blenheim|Picton|Renwick|Springlands|Redwoodtown|Mayfield|Marlborough)\b[^$]{0,70}',
      caseSensitive: false,
    ),
  );
  return suburb ?? 'Address not found';
}

String _size(String text) {
  final values = [
    ?_match(
      text,
      RegExp(
        r'\b\d+\s?(?:bed|beds|bedroom|bedrooms|brm|bdrm)\b',
        caseSensitive: false,
      ),
    ),
    ?_match(
      text,
      RegExp(
        r'\b\d+\s?(?:bath|baths|bathroom|bathrooms)\b',
        caseSensitive: false,
      ),
    ),
    ?_match(
      text,
      RegExp(r'\b\d+\s?(?:m2|sqm|square metres)\b', caseSensitive: false),
    ),
  ];
  return values.isEmpty ? 'Size not found' : values.join(', ');
}

String _agency(String sourceName, String text) {
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
  for (final agency in agencies) {
    if (text.toLowerCase().contains(agency.toLowerCase())) return agency;
  }
  return sourceName;
}

String _contact(String text) {
  final email = _match(
    text,
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
  );
  final phone = _match(
    text,
    RegExp(r'(?:\+64|0)\s?\d{1,3}[\s-]?\d{3}[\s-]?\d{3,4}'),
  );
  if (email != null && phone != null) return '$phone / $email';
  return phone ?? email ?? 'Contact not found';
}

String? _match(String text, RegExp pattern) {
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  return match.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isDuplicate(
  List<RentalScrapedListing> listings,
  RentalScrapedListing listing,
) {
  return listings.any(
    (existing) =>
        existing.source == listing.source ||
        existing.address.toLowerCase() == listing.address.toLowerCase(),
  );
}

String? _absoluteUrl(String baseUrl, String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.hasScheme) return uri.toString();
  return Uri.parse(baseUrl).resolveUri(uri).toString();
}

bool _looksLikeListingUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('rent') ||
      lower.contains('rental') ||
      lower.contains('property') ||
      lower.contains('listing');
}

bool _hasMarlboroughHousingEvidence(String text) {
  if (_hasExcludedHousingLocationEvidence(text)) return false;
  return RegExp(
    r'marlborough|blenheim|renwick|picton|seddon|havelock|springlands|redwoodtown|mayfield|witherlea|riverlands|rapaura|grovetown|riversdale|burleigh|islington|omaka',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _hasExcludedHousingLocationEvidence(String text) {
  return RegExp(
    r'\b(?:auckland|north shore|takapuna|glenfield|albany|manukau|waitakere)\b|wairau[-\s]+valley|archers[-\s]+road',
    caseSensitive: false,
  ).hasMatch(text);
}

String _decodeHtml(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

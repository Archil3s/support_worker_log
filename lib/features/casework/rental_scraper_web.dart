// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'rental_scraper_models.dart';

export 'rental_scraper_models.dart';

const _localScraperUrl = 'http://127.0.0.1:51247';

Future<List<RentalScrapeResult>> scrapeRentalSources(
  List<RentalScrapeSource> sources,
) async {
  html.HttpRequest response;

  try {
    response = await html.HttpRequest.request(
      '$_localScraperUrl/rentals',
      method: 'POST',
      requestHeaders: const {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'sources': [
          for (final source in sources)
            {'name': source.name, 'url': source.url},
        ],
      }),
    ).timeout(const Duration(seconds: 90));
  } on TimeoutException {
    return _failedSources(sources, 'Local scraper timed out.');
  } catch (error) {
    return _failedSources(
      sources,
      'Local scraper is not reachable. Run start_rental_scraper.ps1, then try again.',
    );
  }

  final status = response.status ?? 0;
  final raw = response.responseText ?? '';
  if (status < 200 || status >= 300) {
    return _failedSources(
      sources,
      raw.trim().isEmpty ? 'Local scraper failed with HTTP $status.' : raw,
    );
  }

  final decoded = jsonDecode(raw);
  if (decoded is! Map || decoded['ok'] != true) {
    return _failedSources(sources, 'Local scraper returned invalid data.');
  }

  final results = decoded['results'];
  if (results is! List) {
    return _failedSources(sources, 'Local scraper returned no results.');
  }

  return [
    for (final result in results)
      if (result is Map<String, Object?>)
        RentalScrapeResult(
          sourceName: (result['sourceName'] as String?) ?? 'Rental source',
          listings: _readListings(result['listings']),
          error: result['error'] as String?,
        ),
  ];
}

Future<List<JobScrapeResult>> scrapeJobSources(
  List<JobScrapeSource> sources,
) async {
  html.HttpRequest response;

  try {
    response = await html.HttpRequest.request(
      '$_localScraperUrl/jobs',
      method: 'POST',
      requestHeaders: const {'Content-Type': 'application/json'},
      sendData: jsonEncode({
        'sources': [
          for (final source in sources)
            {'name': source.name, 'url': source.url},
        ],
      }),
    ).timeout(const Duration(seconds: 90));
  } on TimeoutException {
    return _failedJobSources(sources, 'Local scraper timed out.');
  } catch (error) {
    return _failedJobSources(
      sources,
      'Local scraper is not reachable. Run start_rental_scraper.ps1, then try again.',
    );
  }

  final status = response.status ?? 0;
  final raw = response.responseText ?? '';
  if (status < 200 || status >= 300) {
    return _failedJobSources(
      sources,
      raw.trim().isEmpty ? 'Local scraper failed with HTTP $status.' : raw,
    );
  }

  final decoded = jsonDecode(raw);
  if (decoded is! Map || decoded['ok'] != true) {
    return _failedJobSources(sources, 'Local scraper returned invalid data.');
  }

  final results = decoded['results'];
  if (results is! List) {
    return _failedJobSources(sources, 'Local scraper returned no results.');
  }

  return [
    for (final result in results)
      if (result is Map<String, Object?>)
        JobScrapeResult(
          sourceName: (result['sourceName'] as String?) ?? 'Job source',
          listings: _readJobListings(result['listings']),
          error: result['error'] as String?,
        ),
  ];
}

List<JobScrapeResult> _failedJobSources(
  List<JobScrapeSource> sources,
  String message,
) {
  return [
    for (final source in sources)
      JobScrapeResult(
        sourceName: source.name,
        listings: const [],
        error: message,
      ),
  ];
}

List<JobScrapedListing> _readJobListings(Object? value) {
  if (value is! List) return const [];

  return [
    for (final item in value)
      if (item is Map<String, Object?>)
        JobScrapedListing(
          title: (item['title'] as String?) ?? 'Job listing',
          employer: (item['employer'] as String?) ?? 'Employer not found',
          type: (item['type'] as String?) ?? 'Other',
          area: (item['area'] as String?) ?? 'Local area to confirm',
          contact: (item['contact'] as String?) ?? 'Contact not found',
          posted: (item['posted'] as String?) ?? 'Posted date not found',
          quickApply: item['quickApply'] == true,
          source: (item['source'] as String?) ?? '',
          notes: (item['notes'] as String?) ?? '',
        ),
  ];
}

List<RentalScrapeResult> _failedSources(
  List<RentalScrapeSource> sources,
  String message,
) {
  return [
    for (final source in sources)
      RentalScrapeResult(
        sourceName: source.name,
        listings: const [],
        error: message,
      ),
  ];
}

List<RentalScrapedListing> _readListings(Object? value) {
  if (value is! List) return const [];

  return [
    for (final item in value)
      if (item is Map<String, Object?>)
        RentalScrapedListing(
          address: (item['address'] as String?) ?? 'Address not found',
          price: (item['price'] as String?) ?? 'Price not found',
          size: (item['size'] as String?) ?? 'Size not found',
          agency: (item['agency'] as String?) ?? 'Agency not found',
          contact: (item['contact'] as String?) ?? 'Contact not found',
          source: (item['source'] as String?) ?? '',
          notes: (item['notes'] as String?) ?? '',
        ),
  ];
}

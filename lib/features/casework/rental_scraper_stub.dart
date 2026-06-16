import 'rental_scraper_models.dart';

export 'rental_scraper_models.dart';

Future<List<RentalScrapeResult>> scrapeRentalSources(
  List<RentalScrapeSource> sources,
) async {
  return [
    for (final source in sources)
      RentalScrapeResult(
        sourceName: source.name,
        listings: const [],
        error: 'Automatic rental scraping is not available on this platform.',
      ),
  ];
}

Future<List<JobScrapeResult>> scrapeJobSources(
  List<JobScrapeSource> sources,
) async {
  return [
    for (final source in sources)
      JobScrapeResult(
        sourceName: source.name,
        listings: const [],
        error: 'Automatic job scraping is not available on this platform.',
      ),
  ];
}

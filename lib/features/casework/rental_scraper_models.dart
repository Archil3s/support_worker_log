class RentalScrapeSource {
  const RentalScrapeSource({required this.name, required this.url});

  final String name;
  final String url;
}

class RentalScrapedListing {
  const RentalScrapedListing({
    required this.address,
    required this.price,
    required this.size,
    required this.agency,
    required this.contact,
    required this.source,
    required this.notes,
  });

  final String address;
  final String price;
  final String size;
  final String agency;
  final String contact;
  final String source;
  final String notes;
}

class RentalScrapeResult {
  const RentalScrapeResult({
    required this.sourceName,
    required this.listings,
    this.error,
  });

  final String sourceName;
  final List<RentalScrapedListing> listings;
  final String? error;

  bool get blocked => error != null;
}

class JobScrapeSource {
  const JobScrapeSource({required this.name, required this.url});

  final String name;
  final String url;
}

class JobScrapedListing {
  const JobScrapedListing({
    required this.title,
    required this.employer,
    required this.type,
    required this.area,
    required this.contact,
    required this.posted,
    required this.quickApply,
    required this.source,
    required this.notes,
  });

  final String title;
  final String employer;
  final String type;
  final String area;
  final String contact;
  final String posted;
  final bool quickApply;
  final String source;
  final String notes;
}

class JobScrapeResult {
  const JobScrapeResult({
    required this.sourceName,
    required this.listings,
    this.error,
  });

  final String sourceName;
  final List<JobScrapedListing> listings;
  final String? error;

  bool get blocked => error != null;
}

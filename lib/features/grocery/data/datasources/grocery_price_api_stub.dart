import '../../domain/entities/grocery_product.dart';

class GroceryPriceApi {
  const GroceryPriceApi();

  bool get canStartScrape => false;

  Future<GroceryCatalogue> load() {
    throw UnsupportedError(
      'Live grocery prices are not available on this platform.',
    );
  }

  Future<void> startScrape() {
    throw UnsupportedError(
      'Grocery scraping is not available on this platform.',
    );
  }
}

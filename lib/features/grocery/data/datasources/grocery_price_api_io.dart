import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/grocery_product.dart';
import 'grocery_catalogue_decoder.dart';

const _baseUrl = 'http://127.0.0.1:51247';

class GroceryPriceApi {
  const GroceryPriceApi();

  bool get canStartScrape => true;

  Future<GroceryCatalogue> load() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/groceries'));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Local scraper returned ${response.statusCode}.');
      }
      return decodeGroceryCatalogue(body);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> startScrape() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/groceries/scrape'),
      );
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      await response.drain<void>();
      if (response.statusCode != HttpStatus.accepted) {
        throw HttpException('Local scraper returned ${response.statusCode}.');
      }
    } finally {
      client.close(force: true);
    }
  }
}

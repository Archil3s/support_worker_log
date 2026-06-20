// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import '../../domain/entities/grocery_product.dart';
import 'grocery_catalogue_decoder.dart';

const _baseUrl = 'http://127.0.0.1:51247';

class GroceryPriceApi {
  const GroceryPriceApi();

  Future<GroceryCatalogue> load() async {
    final response = await html.HttpRequest.request(
      '$_baseUrl/groceries',
      method: 'GET',
    ).timeout(const Duration(seconds: 10));
    if (response.status != 200) {
      throw StateError('Local scraper returned ${response.status}.');
    }
    return decodeGroceryCatalogue(response.responseText ?? '');
  }

  Future<void> startScrape() async {
    final response = await html.HttpRequest.request(
      '$_baseUrl/groceries/scrape',
      method: 'POST',
      requestHeaders: const {'Content-Type': 'application/json'},
      sendData: '{}',
    ).timeout(const Duration(seconds: 10));
    if (response.status != 202) {
      throw StateError('Local scraper returned ${response.status}.');
    }
  }
}

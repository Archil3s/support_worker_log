// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/services.dart';

import '../../domain/entities/grocery_product.dart';
import 'grocery_catalogue_decoder.dart';

const _configuredBaseUrl = String.fromEnvironment('GROCERY_API_BASE_URL');
const _savedCataloguePath = 'tools/rental_scraper/grocery_prices_blenheim.json';

class GroceryPriceApi {
  const GroceryPriceApi();

  bool get canStartScrape => _baseUrl != null;

  Future<GroceryCatalogue> load() async {
    final baseUrl = _baseUrl;
    if (baseUrl != null) {
      try {
        final response = await html.HttpRequest.request(
          '$baseUrl/groceries',
          method: 'GET',
        ).timeout(const Duration(seconds: 10));
        if (response.status == 200) {
          return decodeGroceryCatalogue(response.responseText ?? '');
        }
      } on Object {
        // The saved catalogue keeps hosted and mobile web usable offline.
      }
    }
    final saved = await rootBundle.loadString(_savedCataloguePath);
    return decodeGroceryCatalogue(saved);
  }

  Future<void> startScrape() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      throw UnsupportedError(
        'Live refresh requires a configured grocery price API.',
      );
    }
    final response = await html.HttpRequest.request(
      '$baseUrl/groceries/scrape',
      method: 'POST',
      requestHeaders: const {'Content-Type': 'application/json'},
      sendData: '{}',
    ).timeout(const Duration(seconds: 10));
    if (response.status != 202) {
      throw StateError('Local scraper returned ${response.status}.');
    }
  }
}

String? get _baseUrl {
  if (_configuredBaseUrl.trim().isNotEmpty) {
    return _configuredBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
  }
  final host = html.window.location.hostname?.toLowerCase() ?? '';
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return 'http://127.0.0.1:51247';
  }
  return null;
}

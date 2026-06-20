import 'dart:convert';

import '../../domain/entities/grocery_product.dart';

GroceryCatalogue decodeGroceryCatalogue(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map ||
      (decoded['ok'] != true && decoded['products'] is! List)) {
    throw const FormatException('Local scraper returned invalid data.');
  }
  final savedSnapshot = decoded['ok'] != true;
  final status = decoded['status'];
  final statusMap = status is Map ? status : const {};
  final rawLocation = decoded['location'];
  final location = rawLocation is Map ? rawLocation : const {};
  final rawProducts = decoded['products'];
  return GroceryCatalogue(
    products: [
      if (rawProducts is List)
        for (final item in rawProducts)
          if (item is Map)
            GroceryProduct.fromJson(Map<String, Object?>.from(item)),
    ].where((product) => product.priceHistory.isNotEmpty).toList(),
    updatedAt: DateTime.tryParse(decoded['updatedAt']?.toString() ?? ''),
    location: GroceryLocation(
      city: location['city']?.toString() ?? 'Blenheim',
      region: location['region']?.toString() ?? 'Marlborough',
      country: location['country']?.toString() ?? 'New Zealand',
    ),
    scraping: statusMap['running'] == true,
    pagesCompleted: _readInt(statusMap['pagesCompleted']),
    pagesTotal: _readInt(statusMap['pagesTotal']),
    error: statusMap['error']?.toString(),
    warning:
        statusMap['warning']?.toString() ??
        (savedSnapshot
            ? 'Showing the latest saved Blenheim catalogue. Live refresh is '
                  'available when the desktop scraper or hosted price API is '
                  'connected.'
            : null),
  );
}

int _readInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

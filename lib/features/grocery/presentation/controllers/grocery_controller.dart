import 'package:flutter/foundation.dart';

import '../../data/datasources/grocery_price_api.dart';
import '../../domain/entities/grocery_product.dart';

class GroceryController extends ChangeNotifier {
  GroceryController({GroceryPriceApi api = const GroceryPriceApi()})
    : _api = api;

  final GroceryPriceApi _api;

  List<GroceryProduct> _catalogue = const [];
  GroceryStore _store = GroceryStore.any;
  GrocerySort _sort = GrocerySort.unitPrice;
  GroceryDiet _diet = GroceryDiet.allCompatible;
  String? _category;
  bool _currentOnly = true;
  bool _loading = false;
  bool _scraping = false;
  int _pagesCompleted = 0;
  int _pagesTotal = 0;
  String? _error;
  String? _warning;
  String _query = '';
  DateTime? _lastUpdated;
  GroceryLocation _location = const GroceryLocation(
    city: 'Blenheim',
    region: 'Marlborough',
    country: 'New Zealand',
  );

  List<GroceryProduct> get products {
    final filtered = [
      for (final product in _catalogue)
        if (product.isCompatibleWith(_diet) &&
            (_store == GroceryStore.any || product.store == _store) &&
            (!_currentOnly || _isCurrent(product)) &&
            (_category == null || product.category == _category) &&
            _matchesQuery(product))
          product,
    ];
    filtered.sort(_compareProducts);
    return filtered;
  }

  GroceryStore get store => _store;
  GrocerySort get sort => _sort;
  GroceryDiet get diet => _diet;
  String? get category => _category;
  bool get currentOnly => _currentOnly;
  bool get loading => _loading;
  bool get scraping => _scraping;
  int get pagesCompleted => _pagesCompleted;
  int get pagesTotal => _pagesTotal;
  String? get error => _error;
  String? get warning => _warning;
  String get query => _query;
  DateTime? get lastUpdated => _lastUpdated;
  String get locationLabel => _location.label;
  List<GroceryProduct> get catalogue => List.unmodifiable(_catalogue);

  List<String> get categories {
    final values = {
      for (final product in _catalogue)
        if (product.isCompatibleWith(_diet) &&
            (_store == GroceryStore.any || product.store == _store) &&
            product.category.trim().isNotEmpty)
          product.category,
    }.toList()..sort();
    return values;
  }

  Future<void> initialise() async {
    await load();
    final updated = _lastUpdated;
    if (updated == null ||
        DateTime.now().difference(updated) > const Duration(hours: 6)) {
      await refreshPrices();
    }
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loading) return;
    _loading = showLoading;
    _error = null;
    notifyListeners();

    try {
      final catalogue = await _api.load();
      _catalogue = catalogue.products;
      _lastUpdated = catalogue.updatedAt;
      _location = catalogue.location;
      _scraping = catalogue.scraping;
      _pagesCompleted = catalogue.pagesCompleted;
      _pagesTotal = catalogue.pagesTotal;
      _error = catalogue.error;
      _warning = catalogue.warning;
    } on Object {
      _error =
          'The local grocery scraper is not running. Restart the desktop app '
          'or run start_rental_scraper.ps1, then retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void search(String value) {
    _query = value.trim().toLowerCase();
    notifyListeners();
  }

  void setStore(GroceryStore value) {
    if (_store == value) return;
    _store = value;
    _category = null;
    notifyListeners();
  }

  Future<void> setCurrentOnly(bool value) async {
    if (_currentOnly == value) return;
    _currentOnly = value;
    notifyListeners();
  }

  Future<void> refreshPrices() async {
    try {
      await _api.startScrape();
      _scraping = true;
      _error = null;
    } on Object {
      _error =
          'The local grocery scraper could not start. Run '
          'start_rental_scraper.ps1 and retry.';
    }
    notifyListeners();
  }

  void setDiet(GroceryDiet value) {
    if (_diet == value) return;
    _diet = value;
    _category = null;
    notifyListeners();
  }

  void setSort(GrocerySort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  void setCategory(String? value) {
    if (_category == value) return;
    _category = value;
    notifyListeners();
  }

  bool _matchesQuery(GroceryProduct product) {
    if (_query.isEmpty) return true;
    final text = '${product.name} ${product.category} ${product.size}'
        .toLowerCase();
    return _query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .every(text.contains);
  }

  bool _isCurrent(GroceryProduct product) {
    final checked = product.lastChecked;
    if (checked == null) return false;
    return DateTime.now().difference(checked) <= const Duration(days: 14);
  }

  int _compareProducts(GroceryProduct left, GroceryProduct right) {
    return switch (_sort) {
      GrocerySort.unitPrice => _compareNullablePrice(
        left.unitPriceValue,
        right.unitPriceValue,
      ),
      GrocerySort.currentPrice => left.currentPrice.compareTo(
        right.currentPrice,
      ),
      GrocerySort.name => left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      ),
    };
  }

  int _compareNullablePrice(double? left, double? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }
}

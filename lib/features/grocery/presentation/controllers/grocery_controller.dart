import 'package:flutter/foundation.dart';

import '../../data/datasources/grocery_price_api.dart';
import '../../domain/entities/grocery_product.dart';

class GroceryController extends ChangeNotifier {
  GroceryController({GroceryPriceApi api = const GroceryPriceApi()})
    : _api = api;

  final GroceryPriceApi _api;

  List<GroceryProduct> _catalogue = const [];
  List<GroceryProduct>? _productsCache;
  List<String>? _categoriesCache;
  GroceryStore _store = GroceryStore.any;
  GrocerySort _sort = GrocerySort.proteinValue;
  GroceryDiet _diet = GroceryDiet.allCompatible;
  String? _category;
  double? _minimumProteinPer100Grams;
  double? _maximumPricePerKilogram;
  bool _currentOnly = true;
  bool _loading = false;
  bool _scraping = false;
  int _pagesCompleted = 0;
  int _pagesTotal = 0;
  int _catalogueRevision = 0;
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
    final cached = _productsCache;
    if (cached != null) return cached;
    final filtered = [
      for (final product in _catalogue)
        if (product.isCompatibleWith(_diet) &&
            (_store == GroceryStore.any || product.store == _store) &&
            (!_currentOnly || _isCurrent(product)) &&
            (_category == null || product.category == _category) &&
            matchesProteinPriceFilters(
              product,
              minimumProteinPer100Grams: _minimumProteinPer100Grams,
              maximumPricePerKilogram: _maximumPricePerKilogram,
            ) &&
            _matchesQuery(product))
          product,
    ];
    filtered.sort(_compareProducts);
    return _productsCache = filtered;
  }

  GroceryStore get store => _store;
  GrocerySort get sort => _sort;
  GroceryDiet get diet => _diet;
  String? get category => _category;
  double? get minimumProteinPer100Grams => _minimumProteinPer100Grams;
  double? get maximumPricePerKilogram => _maximumPricePerKilogram;
  bool get currentOnly => _currentOnly;
  bool get loading => _loading;
  bool get scraping => _scraping;
  int get pagesCompleted => _pagesCompleted;
  int get pagesTotal => _pagesTotal;
  int get catalogueRevision => _catalogueRevision;
  String? get error => _error;
  String? get warning => _warning;
  String get query => _query;
  DateTime? get lastUpdated => _lastUpdated;
  String get locationLabel => _location.label;
  List<GroceryProduct> get catalogue => _catalogue;

  List<String> get categories {
    final cached = _categoriesCache;
    if (cached != null) return cached;
    final values = {
      for (final product in _catalogue)
        if (product.isCompatibleWith(_diet) &&
            (_store == GroceryStore.any || product.store == _store) &&
            product.category.trim().isNotEmpty)
          product.category,
    }.toList()..sort();
    return _categoriesCache = values;
  }

  Future<void> initialise() async {
    await load();
    final updated = _lastUpdated;
    if (_api.canStartScrape &&
        (updated == null ||
            DateTime.now().difference(updated) > const Duration(hours: 6))) {
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
      _invalidateProductViews();
      _catalogueRevision++;
      _lastUpdated = catalogue.updatedAt;
      _location = catalogue.location;
      _scraping = catalogue.scraping;
      _pagesCompleted = catalogue.pagesCompleted;
      _pagesTotal = catalogue.pagesTotal;
      _error = catalogue.error;
      _warning = catalogue.warning;
      if (_catalogue.isNotEmpty &&
          !_catalogue.any(_isCurrent) &&
          _currentOnly) {
        _currentOnly = false;
        _warning =
            '${_warning == null ? '' : '$_warning '}'
            'Current prices were unavailable, so the latest saved prices are '
            'shown.';
      }
    } on Object {
      _error =
          'Grocery prices could not load. On desktop, restart the scraper. '
          'On web, check the deployed saved catalogue or hosted price API.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void search(String value) {
    final query = value.trim().toLowerCase();
    if (_query == query) return;
    _query = query;
    _productsCache = null;
    notifyListeners();
  }

  void setStore(GroceryStore value) {
    if (_store == value) return;
    _store = value;
    _category = null;
    _invalidateProductViews();
    notifyListeners();
  }

  Future<void> setCurrentOnly(bool value) async {
    if (_currentOnly == value) return;
    _currentOnly = value;
    _productsCache = null;
    notifyListeners();
  }

  Future<void> refreshPrices() async {
    if (!_api.canStartScrape) {
      _warning =
          'This web version is showing saved Blenheim prices. Live refresh '
          'requires the hosted grocery price API.';
      notifyListeners();
      return;
    }
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
    if (value == GroceryDiet.keto) {
      _sort = GrocerySort.proteinValue;
    }
    _invalidateProductViews();
    notifyListeners();
  }

  void setSort(GrocerySort value) {
    if (_sort == value) return;
    _sort = value;
    _productsCache = null;
    notifyListeners();
  }

  void setCategory(String? value) {
    if (_category == value) return;
    _category = value;
    _productsCache = null;
    notifyListeners();
  }

  void setMinimumProteinPer100Grams(double? value) {
    if (_minimumProteinPer100Grams == value) return;
    _minimumProteinPer100Grams = value;
    _productsCache = null;
    notifyListeners();
  }

  void setMaximumPricePerKilogram(double? value) {
    if (_maximumPricePerKilogram == value) return;
    _maximumPricePerKilogram = value;
    _productsCache = null;
    notifyListeners();
  }

  void _invalidateProductViews() {
    _productsCache = null;
    _categoriesCache = null;
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
      GrocerySort.proteinValue => _compareProteinValue(left, right),
      GrocerySort.unitPrice => _compareNullablePrice(
        left.pricePerKilogram,
        right.pricePerKilogram,
      ),
      GrocerySort.currentPrice => left.currentPrice.compareTo(
        right.currentPrice,
      ),
      GrocerySort.name => left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      ),
    };
  }

  int _compareProteinValue(GroceryProduct left, GroceryProduct right) {
    final leftValue = left.estimatedProteinGramsPerDollar;
    final rightValue = right.estimatedProteinGramsPerDollar;
    if (leftValue == null && rightValue == null) {
      return _compareNullablePrice(
        left.pricePerKilogram,
        right.pricePerKilogram,
      );
    }
    if (leftValue == null) return 1;
    if (rightValue == null) return -1;
    final protein = rightValue.compareTo(leftValue);
    if (protein != 0) return protein;
    return _compareNullablePrice(left.pricePerKilogram, right.pricePerKilogram);
  }

  int _compareNullablePrice(double? left, double? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }
}

bool matchesProteinPriceFilters(
  GroceryProduct product, {
  double? minimumProteinPer100Grams,
  double? maximumPricePerKilogram,
}) {
  if (minimumProteinPer100Grams != null) {
    final protein = product.estimatedProteinPer100Grams;
    if (protein == null || protein < minimumProteinPer100Grams) return false;
  }
  if (maximumPricePerKilogram != null) {
    final price = product.pricePerKilogram;
    if (price == null || price > maximumPricePerKilogram) return false;
  }
  return true;
}

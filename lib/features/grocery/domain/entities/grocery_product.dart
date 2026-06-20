enum GroceryStore {
  any,
  woolworths,
  paknsave,
  newWorld;

  String get label {
    return switch (this) {
      GroceryStore.any => 'All stores',
      GroceryStore.woolworths => 'Woolworths',
      GroceryStore.paknsave => 'PAK\'nSAVE',
      GroceryStore.newWorld => 'New World',
    };
  }

  String? get sourceSite {
    return switch (this) {
      GroceryStore.any => null,
      GroceryStore.woolworths => 'countdown.co.nz',
      GroceryStore.paknsave => 'paknsave.co.nz',
      GroceryStore.newWorld => 'newworld.co.nz',
    };
  }
}

enum GrocerySort {
  unitPrice,
  currentPrice,
  name;

  String get label {
    return switch (this) {
      GrocerySort.unitPrice => 'Lowest unit price',
      GrocerySort.currentPrice => 'Lowest price',
      GrocerySort.name => 'Product name',
    };
  }
}

enum GroceryDiet {
  allCompatible,
  carnivore,
  keto;

  String get label {
    return switch (this) {
      GroceryDiet.allCompatible => 'Carnivore + keto',
      GroceryDiet.carnivore => 'Carnivore',
      GroceryDiet.keto => 'Keto',
    };
  }
}

class GroceryPricePoint {
  const GroceryPricePoint({required this.date, required this.price});

  final DateTime date;
  final double price;
}

class GroceryProduct {
  const GroceryProduct({
    required this.id,
    required this.name,
    required this.size,
    required this.sourceSite,
    required this.sourceUrl,
    required this.category,
    required this.lastChecked,
    required this.unitPrice,
    required this.priceHistory,
  });

  factory GroceryProduct.fromJson(Map<String, Object?> json) {
    final rawHistory = json['priceHistory'];
    final history = <GroceryPricePoint>[];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is! Map) continue;
        final dateValue = item['date'] ?? item['Date'];
        final priceValue = item['price'] ?? item['Price'];
        final date = DateTime.tryParse(dateValue?.toString() ?? '');
        final price = _readDouble(priceValue);
        if (date != null && price != null) {
          history.add(GroceryPricePoint(date: date, price: price));
        }
      }
    }
    history.sort((left, right) => left.date.compareTo(right.date));

    final categoryValue = json['category'];
    final category = categoryValue is List && categoryValue.isNotEmpty
        ? categoryValue.first.toString()
        : categoryValue?.toString() ?? '';

    return GroceryProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed product',
      size: json['size']?.toString() ?? '',
      sourceSite: _normaliseSource(json['sourceSite']?.toString() ?? ''),
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      category: category,
      lastChecked: DateTime.tryParse(json['lastChecked']?.toString() ?? ''),
      unitPrice: json['unitPrice']?.toString() ?? '',
      priceHistory: history,
    );
  }

  final String id;
  final String name;
  final String size;
  final String sourceSite;
  final String sourceUrl;
  final String category;
  final DateTime? lastChecked;
  final String unitPrice;
  final List<GroceryPricePoint> priceHistory;

  double get currentPrice => priceHistory.isEmpty ? 0 : priceHistory.last.price;

  double? get previousPrice {
    if (priceHistory.length < 2) return null;
    return priceHistory[priceHistory.length - 2].price;
  }

  double? get unitPriceValue {
    final match = RegExp(r'[\d.]+').firstMatch(unitPrice);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  GroceryStore get store {
    final source = sourceSite.toLowerCase();
    if (source.contains('countdown') || source.contains('woolworths')) {
      return GroceryStore.woolworths;
    }
    if (source.contains('paknsave')) return GroceryStore.paknsave;
    if (source.contains('newworld')) return GroceryStore.newWorld;
    return GroceryStore.any;
  }

  double? get priceChangePercent {
    final previous = previousPrice;
    if (previous == null || previous == 0) return null;
    return ((currentPrice - previous) / previous) * 100;
  }

  bool get isDietMarketed {
    return RegExp(
      r'\b(keto|carnivore|low[\s-]?carb|zero[\s-]?carb)\b',
      caseSensitive: false,
    ).hasMatch(name);
  }

  bool get isCarnivoreCompatible {
    final text = '$name $category'.toLowerCase();
    if (_hasCommonDietExclusion(text)) return false;
    if (RegExp(
      r'\b(plant[\s-]?based|vegan|vegetarian|meat[\s-]?free|tofu|soy)\b',
    ).hasMatch(text)) {
      return false;
    }

    const categories = {
      'bacon',
      'beef-lamb',
      'butter',
      'cheese',
      'chicken',
      'cream',
      'deli-meats',
      'eggs',
      'ham',
      'milk',
      'patties-meatballs',
      'pork',
      'salmon',
      'sausages',
      'seafood',
      'yoghurt',
    };
    if (categories.contains(category.toLowerCase())) return true;

    return RegExp(
      r'\b(beef|steak|mince|lamb|mutton|chicken|turkey|pork|bacon|ham|'
      r'sausage|salmon|tuna|sardine|fish|seafood|prawn|mussel|egg|'
      r'butter|cheese|cream|unsweetened yoghurt|greek yoghurt)\b',
    ).hasMatch(text);
  }

  bool get isKetoCompatible {
    final text = '$name $category'.toLowerCase();
    if (_hasCommonDietExclusion(text)) return false;
    if (RegExp(
      r'\b(potato|kumara|sweet potato|corn|rice|pasta|noodle|bread|'
      r'cereal|flour|oat|bean|lentil|chickpea|banana|apple|orange|'
      r'grape|mango|pineapple)\b',
    ).hasMatch(text)) {
      return false;
    }

    if (isCarnivoreCompatible && category != 'milk') return true;

    return RegExp(
      r'\b(avocado|olive oil|coconut oil|spinach|broccoli|cauliflower|'
      r'cabbage|courgette|zucchini|mushroom|lettuce|asparagus|celery|'
      r'cucumber|almond|walnut|macadamia|pecan|chia|unsweetened greek '
      r'yoghurt|natural greek yoghurt)\b',
    ).hasMatch(text);
  }

  bool isCompatibleWith(GroceryDiet diet) {
    if (isDietMarketed) return false;
    return switch (diet) {
      GroceryDiet.allCompatible => isCarnivoreCompatible || isKetoCompatible,
      GroceryDiet.carnivore => isCarnivoreCompatible,
      GroceryDiet.keto => isKetoCompatible,
    };
  }

  String get compatibilityLabel {
    final carnivore = isCarnivoreCompatible;
    final keto = isKetoCompatible;
    if (carnivore && keto) return 'Carnivore + keto';
    if (carnivore) return 'Carnivore';
    if (keto) return 'Keto';
    return 'Check ingredients';
  }
}

class GroceryCatalogue {
  const GroceryCatalogue({
    required this.products,
    required this.updatedAt,
    required this.location,
    required this.scraping,
    required this.pagesCompleted,
    required this.pagesTotal,
    this.error,
    this.warning,
  });

  final List<GroceryProduct> products;
  final DateTime? updatedAt;
  final GroceryLocation location;
  final bool scraping;
  final int pagesCompleted;
  final int pagesTotal;
  final String? error;
  final String? warning;
}

class GroceryLocation {
  const GroceryLocation({
    required this.city,
    required this.region,
    required this.country,
  });

  final String city;
  final String region;
  final String country;

  String get label =>
      [city, region].where((value) => value.isNotEmpty).join(', ');
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _normaliseSource(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('countdown') || lower.contains('woolworths')) {
    return 'countdown.co.nz';
  }
  return value;
}

bool _hasCommonDietExclusion(String text) {
  return RegExp(
    r'\b(sugar|sweetened|honey|syrup|crumbed|breaded|battered|pastry|'
    r'pie|pizza|chocolate|cookie|biscuit|cake|dessert|marinade|glaze|'
    r'sauce|teriyaki|barbecue|bbq)\b',
  ).hasMatch(text);
}

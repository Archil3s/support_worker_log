import '../entities/grocery_product.dart';
import '../entities/grocery_recipe.dart';

class GroceryIngredientPrice {
  const GroceryIngredientPrice({
    required this.ingredient,
    required this.product,
    required this.quantity,
    required this.usedCost,
    required this.purchaseCost,
    required this.packageCount,
    required this.closestMatch,
    required this.substitutionLabel,
  });

  final GroceryIngredient ingredient;
  final GroceryProduct? product;
  final double quantity;
  final double? usedCost;
  final double? purchaseCost;
  final int? packageCount;
  final bool closestMatch;
  final String? substitutionLabel;
}

class GroceryRecipePrice {
  const GroceryRecipePrice({required this.ingredients, required this.people});

  final List<GroceryIngredientPrice> ingredients;
  final int people;

  bool get isComplete => isStockReady;
  bool get isStockReady => ingredients.every(
    (item) => item.ingredient.pantryStaple || item.usedCost != null,
  );

  double get total =>
      ingredients.fold(0, (total, item) => total + (item.usedCost ?? 0));

  double get perServing => people == 0 ? 0 : total / people;
}

class GroceryDayPrice {
  const GroceryDayPrice({
    required this.day,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  final GroceryMealDay day;
  final GroceryRecipePrice breakfast;
  final GroceryRecipePrice lunch;
  final GroceryRecipePrice dinner;

  bool get isComplete =>
      breakfast.isComplete && lunch.isComplete && dinner.isComplete;

  double get total => breakfast.total + lunch.total + dinner.total;
}

class GroceryWeekPrice {
  const GroceryWeekPrice({required this.days, required this.shoppingItems});

  final List<GroceryDayPrice> days;
  final List<GroceryIngredientPrice> shoppingItems;

  bool get isComplete => days.every((day) => day.isComplete);

  double get mealUsageTotal => days.fold(0, (total, day) => total + day.total);

  double get checkoutTotal =>
      shoppingItems.fold(0, (total, item) => total + (item.purchaseCost ?? 0));
}

class PriceGroceryMealPlan {
  const PriceGroceryMealPlan();

  GroceryRecipePrice priceRecipe({
    required GroceryRecipe recipe,
    required int people,
    required List<GroceryProduct> products,
  }) {
    return GroceryRecipePrice(
      people: people,
      ingredients: [
        for (final ingredient in recipe.ingredients)
          _priceIngredient(
            ingredient: ingredient,
            quantity: ingredient.amount * people,
            products: products,
          ),
      ],
    );
  }

  GroceryWeekPrice priceWeek({
    required GroceryRecipeData data,
    required GroceryMealPlan plan,
    required int people,
    required List<GroceryProduct> products,
  }) {
    final days = [
      for (final day in plan.days)
        GroceryDayPrice(
          day: day,
          breakfast: priceRecipe(
            recipe: data.recipe(day.breakfastId),
            people: people,
            products: products,
          ),
          lunch: priceRecipe(
            recipe: data.recipe(day.lunchId),
            people: people,
            products: products,
          ),
          dinner: priceRecipe(
            recipe: data.recipe(day.dinnerId),
            people: people,
            products: products,
          ),
        ),
    ];
    final shopping = buildWeeklyShoppingList(
      data: data,
      plan: plan,
      people: people,
    );
    return GroceryWeekPrice(
      days: days,
      shoppingItems: [
        for (final item in shopping)
          _priceIngredient(
            ingredient: GroceryIngredient(
              id: item.id,
              name: item.name,
              amount: item.amount,
              unit: item.unit,
              category: item.category,
            ),
            quantity: item.amount,
            products: products,
          ),
      ],
    );
  }

  List<GroceryIngredientPrice> priceShoppingList({
    required List<GroceryShoppingItem> items,
    required List<GroceryProduct> products,
  }) {
    return [
      for (final item in items)
        _priceIngredient(
          ingredient: GroceryIngredient(
            id: item.id,
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            category: item.category,
          ),
          quantity: item.amount,
          products: products,
        ),
    ];
  }

  GroceryIngredientPrice _priceIngredient({
    required GroceryIngredient ingredient,
    required double quantity,
    required List<GroceryProduct> products,
  }) {
    final directCandidates = ingredient.pantryStaple
        ? <({GroceryProduct product, int score})>[]
        : products
              .where((product) => product.canPurchase)
              .where((product) => !product.isDietMarketed)
              .where((product) => !_isExcluded(ingredient, product))
              .map(
                (product) =>
                    (product: product, score: _matchScore(ingredient, product)),
              )
              .where((candidate) => candidate.score > 0)
              .toList();
    final substitution = directCandidates.isEmpty
        ? _substitutionFor(ingredient)
        : null;
    final candidates = directCandidates.isNotEmpty
        ? directCandidates
        : substitution == null
        ? <({GroceryProduct product, int score})>[]
        : products
              .where((product) => product.canPurchase)
              .where((product) => !product.isDietMarketed)
              .where((product) => _matchesSubstitution(substitution, product))
              .map((product) => (product: product, score: 1))
              .toList();
    candidates.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final purchase = _purchaseCost(
        left.product,
        quantity,
        ingredient.unit,
      ).compareTo(_purchaseCost(right.product, quantity, ingredient.unit));
      if (purchase != 0) return purchase;
      return _unitCost(left.product).compareTo(_unitCost(right.product));
    });
    final product = candidates.isEmpty ? null : candidates.first.product;
    final packageQuantity = product == null
        ? null
        : _packageQuantity(product, ingredient.unit);
    final usedCost = product == null || packageQuantity == null
        ? null
        : product.currentPrice * quantity / packageQuantity;
    final packageCount = packageQuantity == null
        ? null
        : (quantity / packageQuantity).ceil();

    return GroceryIngredientPrice(
      ingredient: ingredient,
      product: product,
      quantity: quantity,
      usedCost: usedCost,
      purchaseCost: product == null || packageCount == null
          ? null
          : product.currentPrice * packageCount,
      packageCount: packageCount,
      closestMatch:
          product != null &&
          (substitution != null ||
              _usesAliasOrCategoryFallback(ingredient, product)),
      substitutionLabel: product == null || substitution == null
          ? null
          : '${ingredient.name} → ${product.name}',
    );
  }

  _Substitution? _substitutionFor(GroceryIngredient ingredient) {
    final name = _normaliseMatchText(ingredient.name);
    for (final substitution in _substitutions) {
      if (substitution.ingredientPattern.hasMatch(name)) {
        return substitution;
      }
    }
    if (RegExp(r'\bbeef\b|\bribeye\b|\bsteak\b').hasMatch(name)) {
      return _Substitution(
        ingredientPattern: RegExp('never'),
        productTerms: const ['beef'],
        categories: const ['beef-lamb'],
      );
    }
    if (name.contains('chicken')) {
      return _Substitution(
        ingredientPattern: RegExp('never'),
        productTerms: const ['chicken'],
        categories: const ['chicken'],
      );
    }
    if (RegExp(r'\bpork\b|\bham\b').hasMatch(name)) {
      return _Substitution(
        ingredientPattern: RegExp('never'),
        productTerms: const ['pork'],
        categories: const ['pork'],
      );
    }
    if (RegExp(r'\bfish\b|\bshrimp\b|\bprawn\b|\btuna\b').hasMatch(name)) {
      return _Substitution(
        ingredientPattern: RegExp('never'),
        productTerms: const [],
        categories: const ['seafood'],
      );
    }
    if (name.contains('cheese')) {
      return _Substitution(
        ingredientPattern: RegExp('never'),
        productTerms: const ['cheese'],
        categories: const ['cheese'],
      );
    }
    return null;
  }

  bool _matchesSubstitution(
    _Substitution substitution,
    GroceryProduct product,
  ) {
    if (!substitution.categories.contains(product.category.toLowerCase())) {
      return false;
    }
    final terms = _normalisedTerms(product.name);
    return substitution.productTerms.isEmpty ||
        substitution.productTerms.any((term) => _containsTerm(terms, term));
  }

  int _matchScore(GroceryIngredient ingredient, GroceryProduct product) {
    final productText = _normaliseMatchText(product.name);
    final productTerms = _normalisedTerms(productText);
    final requiredTerms = _originalIngredientTerms(ingredient);
    if (requiredTerms.isEmpty) return 0;

    var aliasMatches = 0;
    for (final term in requiredTerms) {
      if (_containsTerm(productTerms, term)) continue;
      final aliases = _termAliases[term] ?? const <String>[];
      if (aliases.any((alias) => _containsTerm(productTerms, alias))) {
        aliasMatches += 1;
        continue;
      }
      return 0;
    }

    var score = (requiredTerms.length * 10) - (aliasMatches * 3);
    final ingredientText = _normaliseMatchText(ingredient.name);
    if (productText.contains(ingredientText)) score += 10;
    score += _categoryScore(ingredient, product);
    if (aliasMatches > 0 && !_categoryCompatible(ingredient, product)) {
      return 0;
    }
    final categoryHint = _categoryHints[ingredient.id];
    if (categoryHint != null &&
        product.category.toLowerCase().contains(categoryHint)) {
      score += 2;
    }
    return score;
  }

  List<String> _originalIngredientTerms(GroceryIngredient ingredient) {
    final explicit = _searchTerms[ingredient.id];
    final source = explicit ?? _normaliseMatchText(ingredient.name).split(' ');
    return source
        .map(_singularTerm)
        .where((term) => term.length > 2 && !_ignoredTerms.contains(term))
        .toSet()
        .toList();
  }

  Set<String> _normalisedTerms(String value) {
    return _normaliseMatchText(
      value,
    ).split(' ').where((term) => term.isNotEmpty).map(_singularTerm).toSet();
  }

  bool _containsTerm(Set<String> productTerms, String term) {
    return productTerms.contains(_singularTerm(term));
  }

  String _singularTerm(String term) {
    final value = term.toLowerCase();
    if (value.endsWith('ies') && value.length > 4) {
      return '${value.substring(0, value.length - 3)}y';
    }
    if (value.endsWith('es') && value.length > 4) {
      return value.substring(0, value.length - 2);
    }
    if (value.endsWith('s') && value.length > 3) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  bool _usesAliasOrCategoryFallback(
    GroceryIngredient ingredient,
    GroceryProduct product,
  ) {
    final productText = _normaliseMatchText(product.name);
    final productTerms = _normalisedTerms(productText);
    return _originalIngredientTerms(
      ingredient,
    ).any((term) => !_containsTerm(productTerms, term));
  }

  String _normaliseMatchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'(?<=[a-z])-\s+(?=[a-z])'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _categoryScore(GroceryIngredient ingredient, GroceryProduct product) {
    return _categoryCompatible(ingredient, product) ? 8 : -8;
  }

  bool _categoryCompatible(
    GroceryIngredient ingredient,
    GroceryProduct product,
  ) {
    final ingredientCategory = ingredient.category.toLowerCase();
    final productCategory = product.category.toLowerCase();
    return switch (ingredientCategory) {
      'meat' => RegExp(
        r'beef|lamb|chicken|pork|sausage|bacon|ham|meat',
      ).hasMatch(productCategory),
      'seafood' => productCategory.contains('seafood'),
      'produce' => productCategory.contains('vegetable'),
      'eggs and dairy' => RegExp(
        r'egg|butter|cheese|cream|yoghurt|milk',
      ).hasMatch(productCategory),
      'pantry' => RegExp(
        r'oil|vinegar|bulk|nut|pantry',
      ).hasMatch(productCategory),
      _ => false,
    };
  }

  double _unitCost(GroceryProduct product) {
    return product.unitPriceValue ?? product.currentPrice;
  }

  double _purchaseCost(GroceryProduct product, double quantity, String unit) {
    final packageQuantity = _packageQuantity(product, unit);
    if (packageQuantity == null) return double.infinity;
    return product.currentPrice * (quantity / packageQuantity).ceil();
  }

  bool _isExcluded(GroceryIngredient ingredient, GroceryProduct product) {
    final ingredientName = _normaliseMatchText(ingredient.name);
    final productName = _normaliseMatchText(product.name);
    if (ingredientName == 'butter') {
      return RegExp(
        r'\b(spread|margarine|garlic|herb|peanut|butterfl)',
      ).hasMatch(productName);
    }
    if (ingredientName == 'cream') {
      return RegExp(
        r'\b(sour|cheese|custard|dessert|ice)\b',
      ).hasMatch(productName);
    }
    return false;
  }

  double? _packageQuantity(GroceryProduct product, String unit) {
    final text = '${product.size} ${product.name}'.toLowerCase();
    if (unit == 'g') {
      final kilograms = RegExp(r'(\d+(?:\.\d+)?)\s*kg\b').firstMatch(text);
      if (kilograms != null) {
        return double.parse(kilograms.group(1)!) * 1000;
      }
      final grams = RegExp(r'(\d+(?:\.\d+)?)\s*g\b').firstMatch(text);
      if (grams != null) return double.parse(grams.group(1)!);
      final unitPrice = product.unitPrice.toLowerCase();
      if (unitPrice.contains('/kg')) {
        final value = product.unitPriceValue;
        return value == null ? null : product.currentPrice / value * 1000;
      }
    }
    if (unit == 'ml') {
      final litres = RegExp(r'(\d+(?:\.\d+)?)\s*l\b').firstMatch(text);
      if (litres != null) return double.parse(litres.group(1)!) * 1000;
      final millilitres = RegExp(r'(\d+(?:\.\d+)?)\s*ml\b').firstMatch(text);
      if (millilitres != null) {
        return double.parse(millilitres.group(1)!);
      }
      final grams = RegExp(r'(\d+(?:\.\d+)?)\s*g\b').firstMatch(text);
      if (grams != null && _allowsApproximateDryMeasure(product)) {
        return double.parse(grams.group(1)!);
      }
      if (product.unitPrice.toLowerCase().contains('/kg') &&
          _allowsApproximateDryMeasure(product)) {
        final value = product.unitPriceValue;
        return value == null ? null : product.currentPrice / value * 1000;
      }
      final unitPrice = product.unitPrice.toLowerCase();
      if (unitPrice.contains('/l')) {
        final value = product.unitPriceValue;
        return value == null ? null : product.currentPrice / value * 1000;
      }
    }
    if (unit == 'each') {
      final pack = RegExp(
        r'(\d+)\s*(?:pack|pk|pieces|piece|count|ct)\b',
      ).firstMatch(text);
      if (pack != null) return double.parse(pack.group(1)!);
      return 1;
    }
    return null;
  }

  bool _allowsApproximateDryMeasure(GroceryProduct product) {
    return RegExp(
      r'\b(flour|powder|sweetener|butter|cheese|peanut|almonds?|'
      r'psyllium|flax|linseed|cocoa|spice|seasoning)\b',
    ).hasMatch(product.name.toLowerCase());
  }
}

class _Substitution {
  _Substitution({
    required this.ingredientPattern,
    required this.productTerms,
    required this.categories,
  });

  final RegExp ingredientPattern;
  final List<String> productTerms;
  final List<String> categories;
}

final _substitutions = <_Substitution>[
  _Substitution(
    ingredientPattern: RegExp(r'\b(coconut flour|almond flour)\b'),
    productTerms: const ['almond'],
    categories: const ['nuts-bulk-mix'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(psyllium|xanthan|guar|flaxseed meal)\b'),
    productTerms: const ['flaxseed', 'linseed'],
    categories: const ['nuts-bulk-mix'],
  ),
  _Substitution(
    ingredientPattern: RegExp(
      r'\b(duck fat|bacon fat|bacon grease|chicken fat|lard)\b',
    ),
    productTerms: const ['butter'],
    categories: const ['butter'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(jalapeno|chilli pepper)\b'),
    productTerms: const ['capsicum'],
    categories: const ['fresh-vegetables'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(coconut milk|coconut cream)\b'),
    productTerms: const ['cream'],
    categories: const ['cream'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(sesame oil|mct oil)\b'),
    productTerms: const ['oil'],
    categories: const ['oils-vinegars'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(pork rinds|chicharrones)\b'),
    productTerms: const ['bacon'],
    categories: const ['pork'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(peanut butter|almond butter)\b'),
    productTerms: const ['almond'],
    categories: const ['nuts-bulk-mix'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\bavocado\b'),
    productTerms: const ['cucumber', 'courgette'],
    categories: const ['fresh-vegetables'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(asparagus|broccoli)\b'),
    productTerms: const ['cauliflower', 'cabbage', 'courgette'],
    categories: const ['fresh-vegetables'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\bcauliflower\b'),
    productTerms: const ['broccoli', 'cabbage', 'courgette'],
    categories: const ['fresh-vegetables'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(courgette|zucchini)\b'),
    productTerms: const ['cauliflower', 'cabbage', 'capsicum'],
    categories: const ['fresh-vegetables'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(spinach|lettuce)\b'),
    productTerms: const ['cabbage', 'lettuce', 'spinach'],
    categories: const ['fresh-vegetables'],
  ),
  _Substitution(
    ingredientPattern: RegExp(r'\b(cucumber|mushroom)\b'),
    productTerms: const ['courgette', 'capsicum', 'cabbage'],
    categories: const ['fresh-vegetables'],
  ),
];

const _searchTerms = <String, List<String>>{
  'eggs': ['egg'],
  'bacon': ['bacon'],
  'butter': ['butter'],
  'cheddar': ['cheddar'],
  'beef_mince': ['beef', 'mince'],
  'beef_steak': ['beef', 'steak'],
  'beef_strips': ['beef', 'strip'],
  'salmon': ['salmon'],
  'chicken_thighs': ['chicken', 'thigh'],
  'chicken_breast': ['chicken', 'breast'],
  'pork_chops': ['pork', 'chop'],
  'lamb_chops': ['lamb', 'chop'],
  'greek_yoghurt': ['greek', 'yoghurt'],
  'walnuts': ['walnut'],
  'avocado': ['avocado'],
  'lettuce': ['lettuce'],
  'olive_oil': ['olive', 'oil'],
  'broccoli': ['broccoli'],
  'cauliflower': ['cauliflower'],
  'cream': ['cream'],
  'cabbage': ['cabbage'],
  'courgette': ['courgette'],
  'ham': ['ham'],
  'tuna': ['tuna'],
  'parmesan': ['parmesan'],
  'almond_flour': ['almond', 'flour'],
  'chicken_stock': ['chicken', 'stock'],
  'pork_sausage': ['pork', 'sausage'],
  'spinach': ['spinach'],
  'green_pepper': ['green', 'capsicum'],
  'beef_stock': ['beef', 'stock'],
  'chicken_wings': ['chicken', 'wing'],
  'cream_cheese': ['cream', 'cheese'],
  'sour_cream': ['sour', 'cream'],
};

const _categoryHints = <String, String>{
  'eggs': 'eggs',
  'butter': 'butter',
  'cheddar': 'cheese',
  'salmon': 'seafood',
};

const _termAliases = <String, List<String>>{
  'jalapeno': ['chilli', 'capsicum', 'pepper'],
  'pepper': ['capsicum'],
  'zucchini': ['courgette'],
  'scallion': ['spring', 'onion'],
  'yogurt': ['yoghurt'],
  'shrimp': ['prawn'],
};

const _ignoredTerms = <String>{
  'fresh',
  'large',
  'medium',
  'small',
  'prepared',
  'raw',
  'ground',
  'natural',
  'heavy',
  'whipping',
  'pure',
  'unsweetened',
  'optional',
  'taste',
};

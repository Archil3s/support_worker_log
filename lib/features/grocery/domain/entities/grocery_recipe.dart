class GroceryIngredient {
  const GroceryIngredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
    this.adaptationNote,
    this.pantryStaple = false,
  });

  factory GroceryIngredient.fromJson(Map<String, Object?> json) {
    return GroceryIngredient(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Other',
      adaptationNote: json['adaptationNote']?.toString(),
      pantryStaple: json['pantryStaple'] == true,
    );
  }

  final String id;
  final String name;
  final double amount;
  final String unit;
  final String category;
  final String? adaptationNote;
  final bool pantryStaple;
}

class GroceryRecipe {
  const GroceryRecipe({
    required this.id,
    required this.name,
    required this.diets,
    required this.minutes,
    required this.ingredients,
    required this.steps,
    required this.cookbookId,
    this.sourcePage,
    this.servings = 1,
    this.calories,
    this.proteinGrams,
    this.netCarbsGrams,
    this.section = '',
    this.sourceIngredients = const [],
    this.supermarketAdapted = false,
  });

  factory GroceryRecipe.fromJson(Map<String, Object?> json) {
    final rawIngredients = json['ingredients'];
    final rawSteps = json['steps'];
    final rawDiets = json['diets'];
    return GroceryRecipe(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      diets: [
        if (rawDiets is List)
          for (final diet in rawDiets) diet.toString(),
      ],
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      ingredients: [
        if (rawIngredients is List)
          for (final ingredient in rawIngredients)
            if (ingredient is Map)
              GroceryIngredient.fromJson(Map<String, Object?>.from(ingredient)),
      ],
      steps: [
        if (rawSteps is List)
          for (final step in rawSteps) step.toString(),
      ],
      cookbookId: json['cookbookId']?.toString() ?? '',
      sourcePage: (json['sourcePage'] as num?)?.toInt(),
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      calories: (json['calories'] as num?)?.toDouble(),
      proteinGrams: (json['proteinGrams'] as num?)?.toDouble(),
      netCarbsGrams: (json['netCarbsGrams'] as num?)?.toDouble(),
      section: json['section']?.toString() ?? '',
      sourceIngredients: [
        if (json['sourceIngredients'] is List)
          for (final ingredient in json['sourceIngredients'] as List)
            ingredient.toString(),
      ],
      supermarketAdapted: json['supermarketAdapted'] == true,
    );
  }

  final String id;
  final String name;
  final List<String> diets;
  final int minutes;
  final List<GroceryIngredient> ingredients;
  final List<String> steps;
  final String cookbookId;
  final int? sourcePage;
  final int servings;
  final double? calories;
  final double? proteinGrams;
  final double? netCarbsGrams;
  final String section;
  final List<String> sourceIngredients;
  final bool supermarketAdapted;

  GroceryRecipe withSourceMetadata(GroceryRecipe source) {
    return GroceryRecipe(
      id: id,
      name: name,
      diets: diets,
      minutes: minutes,
      ingredients: ingredients,
      steps: steps,
      cookbookId: cookbookId,
      sourcePage: sourcePage ?? source.sourcePage,
      servings: servings,
      calories: calories ?? source.calories,
      proteinGrams: proteinGrams ?? source.proteinGrams,
      netCarbsGrams: netCarbsGrams ?? source.netCarbsGrams,
      section: section.isEmpty ? source.section : section,
      sourceIngredients: sourceIngredients.isEmpty
          ? source.sourceIngredients
          : sourceIngredients,
      supermarketAdapted: supermarketAdapted || source.supermarketAdapted,
    );
  }
}

class GroceryCookbook {
  const GroceryCookbook({
    required this.id,
    required this.title,
    required this.author,
    required this.note,
  });

  factory GroceryCookbook.fromJson(Map<String, Object?> json) {
    return GroceryCookbook(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final String author;
  final String note;
}

class GroceryMealDay {
  const GroceryMealDay({
    required this.day,
    required this.breakfastId,
    required this.lunchId,
    required this.dinnerId,
  });

  factory GroceryMealDay.fromJson(Map<String, Object?> json) {
    return GroceryMealDay(
      day: json['day']?.toString() ?? '',
      breakfastId: json['breakfast']?.toString() ?? '',
      lunchId: json['lunch']?.toString() ?? '',
      dinnerId: json['dinner']?.toString() ?? '',
    );
  }

  final String day;
  final String breakfastId;
  final String lunchId;
  final String dinnerId;

  List<String> get recipeIds => [breakfastId, lunchId, dinnerId];
}

class GroceryMealPlan {
  const GroceryMealPlan({
    required this.id,
    required this.name,
    required this.diet,
    required this.days,
    this.budgetNzd,
    this.profile = '',
    this.note = '',
  });

  factory GroceryMealPlan.fromJson(Map<String, Object?> json) {
    final rawDays = json['days'];
    return GroceryMealPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      diet: json['diet']?.toString() ?? '',
      days: [
        if (rawDays is List)
          for (final day in rawDays)
            if (day is Map)
              GroceryMealDay.fromJson(Map<String, Object?>.from(day)),
      ],
      budgetNzd: (json['budgetNzd'] as num?)?.toDouble(),
      profile: json['profile']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String diet;
  final List<GroceryMealDay> days;
  final double? budgetNzd;
  final String profile;
  final String note;
}

class GroceryRecipeData {
  const GroceryRecipeData({
    required this.recipes,
    required this.plans,
    this.cookbooks = const [],
  });

  final List<GroceryRecipe> recipes;
  final List<GroceryMealPlan> plans;
  final List<GroceryCookbook> cookbooks;

  GroceryRecipe recipe(String id) {
    return recipes.firstWhere((recipe) => recipe.id == id);
  }

  GroceryCookbook? cookbook(String id) {
    for (final cookbook in cookbooks) {
      if (cookbook.id == id) return cookbook;
    }
    return null;
  }
}

class GroceryShoppingItem {
  const GroceryShoppingItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
  });

  final String id;
  final String name;
  final double amount;
  final String unit;
  final String category;
}

List<GroceryShoppingItem> buildWeeklyShoppingList({
  required GroceryRecipeData data,
  required GroceryMealPlan plan,
  required int people,
}) {
  final totals = <String, GroceryShoppingItem>{};

  for (final day in plan.days) {
    for (final recipeId in day.recipeIds) {
      final recipe = data.recipe(recipeId);
      for (final ingredient in recipe.ingredients) {
        final key = '${ingredient.id}:${ingredient.unit}';
        final existing = totals[key];
        totals[key] = GroceryShoppingItem(
          id: ingredient.id,
          name: ingredient.name,
          amount: (existing?.amount ?? 0) + (ingredient.amount * people),
          unit: ingredient.unit,
          category: ingredient.category,
        );
      }
    }
  }

  final items = totals.values.toList()
    ..sort((left, right) {
      final category = left.category.compareTo(right.category);
      return category != 0 ? category : left.name.compareTo(right.name);
    });
  return items;
}

List<GroceryShoppingItem> buildSelectedRecipeShoppingList({
  required GroceryRecipeData data,
  required Map<String, int> selectedServings,
}) {
  final totals = <String, GroceryShoppingItem>{};
  for (final selection in selectedServings.entries) {
    if (selection.value <= 0) continue;
    final recipe = data.recipe(selection.key);
    for (final ingredient in recipe.ingredients) {
      final key = '${ingredient.id}:${ingredient.unit}';
      final existing = totals[key];
      totals[key] = GroceryShoppingItem(
        id: ingredient.id,
        name: ingredient.name,
        amount: (existing?.amount ?? 0) + (ingredient.amount * selection.value),
        unit: ingredient.unit,
        category: ingredient.category,
      );
    }
  }
  return totals.values.toList()..sort((left, right) {
    final category = left.category.compareTo(right.category);
    return category != 0 ? category : left.name.compareTo(right.name);
  });
}

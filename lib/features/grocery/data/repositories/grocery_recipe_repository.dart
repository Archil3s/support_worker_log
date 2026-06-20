import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/grocery_recipe.dart';

class GroceryRecipeRepository {
  const GroceryRecipeRepository();

  static const assetPath = 'assets/grocery/keto_carnivore_recipes.json';
  static const importedAssetPath = 'assets/grocery/rm_200_recipes.json';
  static Future<GroceryRecipeData>? _cachedData;

  Future<GroceryRecipeData> load() {
    return _cachedData ??= _load();
  }

  Future<GroceryRecipeData> _load() async {
    final source = await rootBundle.loadString(assetPath);
    final importedSource = await rootBundle.loadString(importedAssetPath);
    final data = decode(source);
    final imported = decodeImported(importedSource);
    final importedByPage = {
      for (final recipe in imported) recipe.sourcePage: recipe,
    };
    final baseRecipes = [
      for (final recipe in data.recipes)
        _mergeSourceMetadata(recipe, importedByPage[recipe.sourcePage]),
    ];
    return GroceryRecipeData(
      recipes: [
        ...baseRecipes,
        ...imported.where(
          (recipe) => !data.recipes.any(
            (existing) =>
                existing.cookbookId == 'rm_200' &&
                existing.sourcePage == recipe.sourcePage,
          ),
        ),
      ],
      plans: data.plans,
      cookbooks: data.cookbooks,
    );
  }

  GroceryRecipe _mergeSourceMetadata(
    GroceryRecipe recipe,
    GroceryRecipe? source,
  ) {
    if (recipe.cookbookId != 'rm_200' || source == null) return recipe;
    return recipe.withSourceMetadata(source);
  }

  List<GroceryRecipe> decodeImported(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['recipes'] is! List) {
      throw const FormatException('Imported recipe data is invalid.');
    }
    return [
      for (final recipe in decoded['recipes'] as List)
        if (recipe is Map)
          GroceryRecipe.fromJson(Map<String, Object?>.from(recipe)),
    ];
  }

  GroceryRecipeData decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Recipe data is invalid.');
    }
    final recipes = decoded['recipes'];
    final plans = decoded['plans'];
    final cookbooks = decoded['cookbooks'];
    return GroceryRecipeData(
      recipes: [
        if (recipes is List)
          for (final recipe in recipes)
            if (recipe is Map)
              GroceryRecipe.fromJson(Map<String, Object?>.from(recipe)),
      ],
      plans: [
        if (plans is List)
          for (final plan in plans)
            if (plan is Map)
              GroceryMealPlan.fromJson(Map<String, Object?>.from(plan)),
      ],
      cookbooks: [
        if (cookbooks is List)
          for (final cookbook in cookbooks)
            if (cookbook is Map)
              GroceryCookbook.fromJson(Map<String, Object?>.from(cookbook)),
      ],
    );
  }
}

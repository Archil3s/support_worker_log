import '../entities/grocery_product.dart';
import '../entities/grocery_recipe.dart';
import 'price_grocery_meal_plan.dart';

class SuggestBudgetKetoPlan {
  const SuggestBudgetKetoPlan({this.pricer = const PriceGroceryMealPlan()});

  final PriceGroceryMealPlan pricer;

  GroceryMealPlan call({
    required GroceryRecipeData data,
    required GroceryMealPlan basePlan,
    required List<GroceryProduct> products,
    required int variation,
  }) {
    final budget = basePlan.budgetNzd;
    if (budget == null || products.isEmpty) return basePlan;

    final allCandidates = data.recipes
        .where((recipe) => recipe.cookbookId == 'rm_200')
        .where((recipe) => recipe.diets.contains('keto'))
        .where((recipe) => _mealSections.contains(recipe.section))
        .where((recipe) => (recipe.netCarbsGrams ?? 0) <= 12)
        .toList();
    if (allCandidates.isEmpty) return _reordered(basePlan, variation);
    final candidateOffset = variation.abs() % allCandidates.length;
    final candidatesToPrice = [
      ...allCandidates.skip(candidateOffset),
      ...allCandidates.take(candidateOffset),
    ].take(24);
    final pricedCandidates = candidatesToPrice
        .map(
          (recipe) => (
            recipe: recipe,
            price: pricer.priceRecipe(
              recipe: recipe,
              people: 1,
              products: products,
            ),
          ),
        )
        .where((candidate) {
          final price = candidate.price;
          return price.isComplete && price.total <= 10;
        })
        .toList();
    if (pricedCandidates.isEmpty) return _reordered(basePlan, variation);

    pricedCandidates.sort(_compareProteinValue);
    final candidates = [
      for (final candidate in pricedCandidates) candidate.recipe,
    ];

    var suggested = _reordered(basePlan, variation);
    var suggestedPrice = pricer.priceWeek(
      data: data,
      plan: suggested,
      people: 1,
      products: products,
    );
    final offset = variation.abs() % candidates.length;
    final rotated = [...candidates.skip(offset), ...candidates.take(offset)];
    var accepted = 0;

    for (final recipe in rotated) {
      if (accepted == 6) break;
      final slot = _slotFor(recipe.section, variation + accepted);
      final replacement = _replace(suggested, slot, recipe.id);
      final replacementPrice = pricer.priceWeek(
        data: data,
        plan: replacement,
        people: 1,
        products: products,
      );
      final withinBudget = replacementPrice.checkoutTotal <= budget;
      final improvesBudget =
          suggestedPrice.checkoutTotal > budget &&
          replacementPrice.checkoutTotal < suggestedPrice.checkoutTotal;
      if (!replacementPrice.isComplete || (!withinBudget && !improvesBudget)) {
        continue;
      }
      suggested = replacement;
      suggestedPrice = replacementPrice;
      accepted++;
    }

    return GroceryMealPlan(
      id: '${basePlan.id}_suggested_$variation',
      name: basePlan.name,
      diet: basePlan.diet,
      days: suggested.days,
      budgetNzd: budget,
      profile: basePlan.profile,
      note: accepted == 0
          ? 'Alternative budget menu using the lowest-cost available meals.'
          : 'Alternative $variation uses $accepted keto cookbook meals and '
                'current Blenheim catalogue prices.',
    );
  }

  GroceryMealPlan replaceMeal({
    required GroceryRecipeData data,
    required GroceryMealPlan plan,
    required List<GroceryProduct> products,
    required int dayIndex,
    required String meal,
    required int variation,
  }) {
    if (dayIndex < 0 || dayIndex >= plan.days.length || products.isEmpty) {
      return plan;
    }
    final currentId = switch (meal) {
      'Breakfast' => plan.days[dayIndex].breakfastId,
      'Lunch' => plan.days[dayIndex].lunchId,
      'Dinner' => plan.days[dayIndex].dinnerId,
      _ => '',
    };
    final allCandidates = data.recipes
        .where((recipe) => recipe.id != currentId)
        .where((recipe) => recipe.cookbookId == 'rm_200')
        .where((recipe) => recipe.diets.contains('keto'))
        .where((recipe) => recipe.section == meal)
        .where((recipe) => (recipe.netCarbsGrams ?? 0) <= 12)
        .toList();
    if (allCandidates.isEmpty) return plan;
    final candidateOffset = variation.abs() % allCandidates.length;
    final candidatesToPrice = [
      ...allCandidates.skip(candidateOffset),
      ...allCandidates.take(candidateOffset),
    ].take(18);
    final candidates =
        candidatesToPrice
            .map(
              (recipe) => (
                recipe: recipe,
                price: pricer.priceRecipe(
                  recipe: recipe,
                  people: 1,
                  products: products,
                ),
              ),
            )
            .where((candidate) => candidate.price.isComplete)
            .toList()
          ..sort(_compareProteinValue);
    if (candidates.isEmpty) return plan;

    final offset = variation.abs() % candidates.length;
    final rotated = [...candidates.skip(offset), ...candidates.take(offset)];
    final currentPrice = pricer.priceWeek(
      data: data,
      plan: plan,
      people: 1,
      products: products,
    );
    for (final candidate in rotated) {
      final replacement = _replace(plan, (
        day: dayIndex,
        meal: meal,
      ), candidate.recipe.id);
      final replacementPrice = pricer.priceWeek(
        data: data,
        plan: replacement,
        people: 1,
        products: products,
      );
      final budget = plan.budgetNzd;
      if (budget == null ||
          replacementPrice.checkoutTotal <= budget ||
          (currentPrice.checkoutTotal > budget &&
              replacementPrice.checkoutTotal < currentPrice.checkoutTotal)) {
        return GroceryMealPlan(
          id: plan.id,
          name: plan.name,
          diet: plan.diet,
          days: replacement.days,
          budgetNzd: plan.budgetNzd,
          profile: plan.profile,
          note: plan.note,
        );
      }
    }
    return plan;
  }

  GroceryMealPlan _reordered(GroceryMealPlan plan, int variation) {
    if (plan.days.isEmpty) return plan;
    final offset = variation.abs() % plan.days.length;
    final meals = [...plan.days.skip(offset), ...plan.days.take(offset)];
    return GroceryMealPlan(
      id: plan.id,
      name: plan.name,
      diet: plan.diet,
      days: [
        for (var index = 0; index < meals.length; index++)
          GroceryMealDay(
            day: plan.days[index].day,
            breakfastId: meals[index].breakfastId,
            lunchId: meals[index].lunchId,
            dinnerId: meals[index].dinnerId,
          ),
      ],
      budgetNzd: plan.budgetNzd,
      profile: plan.profile,
      note: plan.note,
    );
  }

  GroceryMealPlan _replace(
    GroceryMealPlan plan,
    ({int day, String meal}) slot,
    String recipeId,
  ) {
    return GroceryMealPlan(
      id: plan.id,
      name: plan.name,
      diet: plan.diet,
      days: [
        for (var index = 0; index < plan.days.length; index++)
          if (index != slot.day)
            plan.days[index]
          else
            GroceryMealDay(
              day: plan.days[index].day,
              breakfastId: slot.meal == 'Breakfast'
                  ? recipeId
                  : plan.days[index].breakfastId,
              lunchId: slot.meal == 'Lunch'
                  ? recipeId
                  : plan.days[index].lunchId,
              dinnerId: slot.meal == 'Dinner'
                  ? recipeId
                  : plan.days[index].dinnerId,
            ),
      ],
      budgetNzd: plan.budgetNzd,
      profile: plan.profile,
      note: plan.note,
    );
  }

  ({int day, String meal}) _slotFor(String section, int variation) {
    return (day: variation.abs() % 7, meal: section);
  }

  int _compareProteinValue(
    ({GroceryRecipe recipe, GroceryRecipePrice price}) left,
    ({GroceryRecipe recipe, GroceryRecipePrice price}) right,
  ) {
    final leftProtein = left.recipe.proteinGrams;
    final rightProtein = right.recipe.proteinGrams;
    final leftValue = leftProtein == null || left.price.total <= 0
        ? null
        : leftProtein / left.price.total;
    final rightValue = rightProtein == null || right.price.total <= 0
        ? null
        : rightProtein / right.price.total;
    if (leftValue == null && rightValue == null) {
      return left.price.total.compareTo(right.price.total);
    }
    if (leftValue == null) return 1;
    if (rightValue == null) return -1;
    final proteinValue = rightValue.compareTo(leftValue);
    if (proteinValue != 0) return proteinValue;
    final protein = rightProtein!.compareTo(leftProtein!);
    if (protein != 0) return protein;
    return left.price.total.compareTo(right.price.total);
  }
}

const _mealSections = {'Breakfast', 'Lunch', 'Dinner'};

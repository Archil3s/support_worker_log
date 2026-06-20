import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/features/grocery/data/repositories/grocery_recipe_repository.dart';
import 'package:support_worker_log/features/grocery/domain/entities/grocery_recipe.dart';
import 'package:support_worker_log/features/grocery/domain/entities/grocery_product.dart';
import 'package:support_worker_log/features/grocery/domain/usecases/price_grocery_meal_plan.dart';
import 'package:support_worker_log/features/grocery/domain/usecases/suggest_budget_keto_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads keto and carnivore weekly plans from the data file', () async {
    final data = await const GroceryRecipeRepository().load();

    expect(data.plans.map((plan) => plan.id), contains('carnivore_week'));
    expect(data.plans.map((plan) => plan.id), contains('keto_week'));
    expect(data.plans.map((plan) => plan.id), contains('rm_cookbook_week'));
    final budgetPlan = data.plans.singleWhere(
      (plan) => plan.id == 'budget_keto_80',
    );
    expect(budgetPlan.budgetNzd, 80);
    expect(budgetPlan.profile, contains('112 kg'));
    expect(budgetPlan.note, contains('not a personalised calorie'));
    final budgetShopping = buildWeeklyShoppingList(
      data: data,
      plan: budgetPlan,
      people: 1,
    );
    expect(budgetShopping.singleWhere((item) => item.id == 'eggs').amount, 12);
    expect(
      budgetShopping.singleWhere((item) => item.id == 'chicken_thighs').amount,
      3900,
    );
    expect(
      budgetShopping.singleWhere((item) => item.id == 'beef_mince').amount,
      400,
    );
    expect(
      budgetShopping.singleWhere((item) => item.id == 'butter').amount,
      350,
    );
    expect(data.plans.every((plan) => plan.days.length == 7), isTrue);
    expect(data.cookbooks, hasLength(4));
    final imported = data.recipes.where(
      (recipe) => recipe.cookbookId == 'rm_200',
    );
    expect(imported, hasLength(180));
    expect(imported.every((recipe) => recipe.sourcePage != null), isTrue);
    expect(imported.map((recipe) => recipe.section).toSet(), {
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snacks',
      'Sides',
      'Desserts',
    });
    expect(
      imported.every((recipe) => recipe.sourceIngredients.isNotEmpty),
      isTrue,
    );
    expect(imported.every((recipe) => recipe.ingredients.isNotEmpty), isTrue);
    expect(imported.every((recipe) => recipe.supermarketAdapted), isTrue);
    final breakfastBurger = imported.singleWhere(
      (recipe) => recipe.sourcePage == 11,
    );
    expect(
      breakfastBurger.ingredients.map((item) => item.name),
      containsAll(['Tasty Cheese', 'Natural Peanut Butter']),
    );
    expect(
      breakfastBurger.ingredients
          .singleWhere((item) => item.name == 'Natural Peanut Butter')
          .category,
      'Pantry',
    );
    expect(
      imported.expand((recipe) => recipe.ingredients).map((item) => item.name),
      containsAll(['Ground Almonds', 'Ground Flaxseed']),
    );
    expect(
      imported
          .expand((recipe) => recipe.ingredients)
          .where((item) => item.pantryStaple),
      isNotEmpty,
    );
    expect(data.recipe('rm_bacon_cheddar_omelette').proteinGrams, 24);
    expect(
      data.recipes.where((recipe) => recipe.diets.contains('keto')),
      everyElement(
        isA<GroceryRecipe>().having(
          (recipe) => recipe.cookbookId,
          'cookbookId',
          isNotEmpty,
        ),
      ),
    );
  });

  test('weekly shopping list aggregates repeated ingredients', () {
    const eggs = GroceryIngredient(
      id: 'eggs',
      name: 'Eggs',
      amount: 2,
      unit: 'each',
      category: 'Eggs and dairy',
    );
    const recipe = GroceryRecipe(
      id: 'eggs',
      name: 'Eggs',
      diets: ['carnivore'],
      minutes: 5,
      ingredients: [eggs],
      steps: [],
      cookbookId: 'test',
    );
    const day = GroceryMealDay(
      day: 'Monday',
      breakfastId: 'eggs',
      lunchId: 'eggs',
      dinnerId: 'eggs',
    );
    const data = GroceryRecipeData(recipes: [recipe], plans: []);
    const plan = GroceryMealPlan(
      id: 'week',
      name: 'Week',
      diet: 'carnivore',
      days: [day],
    );

    final list = buildWeeklyShoppingList(data: data, plan: plan, people: 2);

    expect(list.single.name, 'Eggs');
    expect(list.single.amount, 12);
  });

  test('selected recipes build a combined shopping list by servings', () {
    const eggs = GroceryIngredient(
      id: 'eggs',
      name: 'Eggs',
      amount: 2,
      unit: 'each',
      category: 'Eggs and dairy',
    );
    const butter = GroceryIngredient(
      id: 'butter',
      name: 'Butter',
      amount: 10,
      unit: 'g',
      category: 'Eggs and dairy',
    );
    const recipe = GroceryRecipe(
      id: 'omelette',
      name: 'Omelette',
      diets: ['keto'],
      minutes: 10,
      ingredients: [eggs, butter],
      steps: [],
      cookbookId: 'test',
    );
    const data = GroceryRecipeData(recipes: [recipe], plans: []);

    final list = buildSelectedRecipeShoppingList(
      data: data,
      selectedServings: {'omelette': 3},
    );

    expect(list.singleWhere((item) => item.id == 'eggs').amount, 6);
    expect(list.singleWhere((item) => item.id == 'butter').amount, 30);
  });

  test('budget shuffle draws on keto cookbook recipes under the limit', () {
    const baseRecipe = GroceryRecipe(
      id: 'base',
      name: 'Base eggs',
      diets: ['keto'],
      minutes: 5,
      ingredients: [
        GroceryIngredient(
          id: 'eggs',
          name: 'Eggs',
          amount: 1,
          unit: 'each',
          category: 'Eggs and dairy',
        ),
      ],
      steps: [],
      cookbookId: 'budget',
    );
    const cookbookRecipe = GroceryRecipe(
      id: 'cookbook',
      name: 'Cookbook eggs',
      diets: ['keto'],
      minutes: 5,
      ingredients: [
        GroceryIngredient(
          id: 'eggs',
          name: 'Eggs',
          amount: 2,
          unit: 'each',
          category: 'Eggs and dairy',
        ),
      ],
      steps: [],
      cookbookId: 'rm_200',
      section: 'Breakfast',
      netCarbsGrams: 1,
    );
    const days = [
      GroceryMealDay(
        day: 'Monday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
      GroceryMealDay(
        day: 'Tuesday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
      GroceryMealDay(
        day: 'Wednesday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
      GroceryMealDay(
        day: 'Thursday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
      GroceryMealDay(
        day: 'Friday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
      GroceryMealDay(
        day: 'Saturday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
      GroceryMealDay(
        day: 'Sunday',
        breakfastId: 'base',
        lunchId: 'base',
        dinnerId: 'base',
      ),
    ];
    const plan = GroceryMealPlan(
      id: 'budget_keto_80',
      name: 'Budget keto',
      diet: 'keto',
      days: days,
      budgetNzd: 80,
    );
    const data = GroceryRecipeData(
      recipes: [baseRecipe, cookbookRecipe],
      plans: [plan],
    );
    final eggs = GroceryProduct.fromJson({
      'id': 'eggs',
      'name': 'Free Range Eggs 12 Pack',
      'size': '12pk',
      'category': 'eggs',
      'sourceSite': 'paknsave.co.nz',
      'sourceUrl': 'https://www.paknsave.co.nz/shop/product/eggs',
      'lastChecked': '2026-06-20',
      'priceHistory': [
        {'date': '2026-06-20', 'price': 10},
      ],
    });

    final suggested = const SuggestBudgetKetoPlan()(
      data: data,
      basePlan: plan,
      products: [eggs],
      variation: 1,
    );
    final price = const PriceGroceryMealPlan().priceWeek(
      data: data,
      plan: suggested,
      people: 1,
      products: [eggs],
    );

    expect(suggested.days.expand((day) => day.recipeIds), contains('cookbook'));
    expect(price.checkoutTotal, lessThanOrEqualTo(80));
  });

  test('individual meal swap uses a priced same-section keto recipe', () {
    const baseRecipe = GroceryRecipe(
      id: 'base',
      name: 'Base breakfast',
      diets: ['keto'],
      minutes: 5,
      ingredients: [
        GroceryIngredient(
          id: 'eggs',
          name: 'Eggs',
          amount: 1,
          unit: 'each',
          category: 'Eggs and dairy',
        ),
      ],
      steps: [],
      cookbookId: 'budget',
    );
    const alternative = GroceryRecipe(
      id: 'alternative',
      name: 'Cookbook breakfast',
      diets: ['keto'],
      minutes: 5,
      ingredients: [
        GroceryIngredient(
          id: 'eggs',
          name: 'Eggs',
          amount: 2,
          unit: 'each',
          category: 'Eggs and dairy',
        ),
      ],
      steps: [],
      cookbookId: 'rm_200',
      section: 'Breakfast',
      netCarbsGrams: 2,
    );
    const day = GroceryMealDay(
      day: 'Monday',
      breakfastId: 'base',
      lunchId: 'base',
      dinnerId: 'base',
    );
    const plan = GroceryMealPlan(
      id: 'keto',
      name: 'Keto',
      diet: 'keto',
      days: [day],
    );
    const data = GroceryRecipeData(
      recipes: [baseRecipe, alternative],
      plans: [plan],
    );
    final eggs = GroceryProduct.fromJson({
      'id': 'eggs',
      'name': 'Free Range Eggs 12 Pack',
      'size': '12pk',
      'category': 'eggs',
      'sourceSite': 'paknsave.co.nz',
      'sourceUrl': 'https://www.paknsave.co.nz/shop/product/eggs',
      'lastChecked': '2026-06-20',
      'priceHistory': [
        {'date': '2026-06-20', 'price': 10},
      ],
    });

    final result = const SuggestBudgetKetoPlan().replaceMeal(
      data: data,
      plan: plan,
      products: [eggs],
      dayIndex: 0,
      meal: 'Breakfast',
      variation: 0,
    );

    expect(result.days.single.breakfastId, 'alternative');
    expect(result.days.single.lunchId, 'base');
  });

  test('prices a keto recipe from a matching Blenheim product', () {
    const ingredient = GroceryIngredient(
      id: 'beef_mince',
      name: 'Beef mince',
      amount: 250,
      unit: 'g',
      category: 'Meat',
    );
    const recipe = GroceryRecipe(
      id: 'mince',
      name: 'Beef mince',
      diets: ['keto'],
      minutes: 10,
      ingredients: [ingredient],
      steps: [],
      cookbookId: 'test',
    );
    final product = GroceryProduct.fromJson({
      'id': 'beef-mince-1',
      'name': 'NZ Beef Mince 500g',
      'size': '500g',
      'category': 'beef-lamb',
      'sourceSite': 'paknsave.co.nz',
      'sourceUrl': 'https://www.paknsave.co.nz/shop/product/beef-mince-1',
      'unitPrice': r'$20/kg',
      'lastChecked': '2026-06-19',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 10},
      ],
    });

    final price = const PriceGroceryMealPlan().priceRecipe(
      recipe: recipe,
      people: 2,
      products: [product],
    );

    expect(price.isComplete, isTrue);
    expect(price.total, 10);
    expect(price.perServing, 5);
    expect(price.ingredients.single.purchaseCost, 10);
    expect(price.ingredients.single.packageCount, 1);
    expect(
      price.ingredients.single.product?.sourceUrl,
      contains('paknsave.co.nz'),
    );
  });

  test('uses fresh capsicum as closest match for jalapeno peppers', () {
    const ingredient = GroceryIngredient(
      id: 'jalapeno_peppers',
      name: 'Jalapeno Peppers',
      amount: 1,
      unit: 'each',
      category: 'Produce',
    );
    const recipe = GroceryRecipe(
      id: 'jalapeno',
      name: 'Jalapeno meal',
      diets: ['keto'],
      minutes: 10,
      ingredients: [ingredient],
      steps: [],
      cookbookId: 'test',
    );
    final capsicum = GroceryProduct.fromJson({
      'id': 'capsicum',
      'name': 'Green Capsicum',
      'size': 'ea',
      'category': 'fresh-vegetables',
      'sourceSite': 'newworld.co.nz',
      'sourceUrl': 'https://www.newworld.co.nz/shop/product/capsicum',
      'unitPrice': r'$4.49/ea',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 4.49},
      ],
    });
    final sausage = GroceryProduct.fromJson({
      'id': 'sausage',
      'name': 'Pork Jalapeno and Cheddar Sausage',
      'size': '420g',
      'category': 'pork',
      'sourceSite': 'paknsave.co.nz',
      'sourceUrl': 'https://www.paknsave.co.nz/shop/product/sausage',
      'unitPrice': r'$23.79/kg',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 9.99},
      ],
    });

    final price = const PriceGroceryMealPlan().priceRecipe(
      recipe: recipe,
      people: 1,
      products: [sausage, capsicum],
    );

    expect(price.ingredients.single.product?.name, 'Green Capsicum');
    expect(price.ingredients.single.closestMatch, isTrue);
  });

  test('does not match specialty powders to oil or vinegar', () {
    const recipe = GroceryRecipe(
      id: 'waffles',
      name: 'Keto waffles',
      diets: ['keto'],
      minutes: 10,
      ingredients: [
        GroceryIngredient(
          id: 'coconut_flour',
          name: 'Coconut Flour',
          amount: 15,
          unit: 'g',
          category: 'Pantry',
        ),
        GroceryIngredient(
          id: 'psyllium_husk_powder',
          name: 'Psyllium Husk Powder',
          amount: 5,
          unit: 'g',
          category: 'Pantry',
        ),
        GroceryIngredient(
          id: 'baking_powder',
          name: 'Baking Powder',
          amount: 5,
          unit: 'g',
          category: 'Pantry',
        ),
      ],
      steps: [],
      cookbookId: 'test',
    );
    final coconutOil = GroceryProduct.fromJson({
      'id': 'oil',
      'name': 'Pams Coconut Oil',
      'size': '400ml',
      'category': 'oils-vinegars',
      'sourceSite': 'newworld.co.nz',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 6.45},
      ],
    });
    final vinegar = GroceryProduct.fromJson({
      'id': 'vinegar',
      'name': 'Pams White Vinegar',
      'size': '750ml',
      'category': 'oils-vinegars',
      'sourceSite': 'newworld.co.nz',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 1.69},
      ],
    });

    final price = const PriceGroceryMealPlan().priceRecipe(
      recipe: recipe,
      people: 1,
      products: [coconutOil, vinegar],
    );

    expect(price.ingredients.every((item) => item.product == null), isTrue);
    expect(price.total, 0);
    expect(price.isComplete, isFalse);
  });

  test('matches supermarket ground almonds to bulk whole almonds', () {
    const recipe = GroceryRecipe(
      id: 'almond',
      name: 'Almond base',
      diets: ['keto'],
      minutes: 10,
      ingredients: [
        GroceryIngredient(
          id: 'ground_almonds',
          name: 'Ground Almonds',
          amount: 100,
          unit: 'g',
          category: 'Pantry',
        ),
      ],
      steps: [],
      cookbookId: 'test',
    );
    final almonds = GroceryProduct.fromJson({
      'id': 'almonds',
      'name': 'Whole Natural Almonds',
      'size': 'per kg',
      'category': 'nuts-bulk-mix',
      'sourceSite': 'paknsave.co.nz',
      'unitPrice': r'$36.50/kg',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 36.50},
      ],
    });

    final price = const PriceGroceryMealPlan().priceRecipe(
      recipe: recipe,
      people: 1,
      products: [almonds],
    );

    expect(price.isComplete, isTrue);
    expect(price.ingredients.single.product?.name, 'Whole Natural Almonds');
    expect(price.total, 3.65);
  });

  test('substitutes coconut flour with stocked almonds', () {
    const recipe = GroceryRecipe(
      id: 'coconut-flour',
      name: 'Coconut flour recipe',
      diets: ['keto'],
      minutes: 10,
      ingredients: [
        GroceryIngredient(
          id: 'coconut_flour',
          name: 'Coconut Flour',
          amount: 30,
          unit: 'ml',
          category: 'Pantry',
        ),
      ],
      steps: [],
      cookbookId: 'test',
    );
    final almonds = GroceryProduct.fromJson({
      'id': 'almonds',
      'name': 'Whole Natural Almonds',
      'size': 'per kg',
      'category': 'nuts-bulk-mix',
      'sourceSite': 'paknsave.co.nz',
      'unitPrice': r'$36.50/kg',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 36.50},
      ],
    });

    final price = const PriceGroceryMealPlan().priceRecipe(
      recipe: recipe,
      people: 1,
      products: [almonds],
    );

    expect(price.isComplete, isTrue);
    expect(price.ingredients.single.product?.name, 'Whole Natural Almonds');
    expect(price.ingredients.single.substitutionLabel, contains('Coconut'));
  });

  test('replaces unavailable seasonal produce with a keto vegetable', () {
    const ingredient = GroceryIngredient(
      id: 'avocado',
      name: 'Avocado',
      amount: 1,
      unit: 'each',
      category: 'Produce',
    );
    const recipe = GroceryRecipe(
      id: 'avocado_meal',
      name: 'Avocado meal',
      diets: ['keto'],
      minutes: 5,
      ingredients: [ingredient],
      steps: [],
      cookbookId: 'test',
    );
    final unavailableAvocado = GroceryProduct.fromJson({
      'id': 'avocado',
      'name': 'Fresh Avocado',
      'size': 'ea',
      'category': 'fresh-vegetables',
      'sourceSite': 'newworld.co.nz',
      'sourceUrl': 'https://www.newworld.co.nz/avocado',
      'available': false,
      'lastChecked': '2026-06-20',
      'priceHistory': [
        {'date': '2026-06-20', 'price': 3},
      ],
    });
    final cucumber = GroceryProduct.fromJson({
      'id': 'cucumber',
      'name': 'Telegraph Cucumber',
      'size': 'ea',
      'category': 'fresh-vegetables',
      'sourceSite': 'paknsave.co.nz',
      'sourceUrl': 'https://www.paknsave.co.nz/cucumber',
      'lastChecked': '2026-06-20',
      'priceHistory': [
        {'date': '2026-06-20', 'price': 2},
      ],
    });

    final price = const PriceGroceryMealPlan().priceRecipe(
      recipe: recipe,
      people: 1,
      products: [unavailableAvocado, cucumber],
    );

    expect(price.isComplete, isTrue);
    expect(price.ingredients.single.product?.id, 'cucumber');
    expect(price.ingredients.single.substitutionLabel, contains('Avocado'));
  });
}

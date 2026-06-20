import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/grocery_recipe_repository.dart';
import '../../domain/entities/grocery_product.dart';
import '../../domain/entities/grocery_recipe.dart';
import '../../domain/usecases/price_grocery_meal_plan.dart';
import '../../domain/usecases/suggest_budget_keto_plan.dart';

const _panel = Color(0xFF151B29);
const _border = Color(0xFF34405F);
const _muted = Color(0xFF8396C7);
const _blue = Color(0xFF4F8DF7);
const _green = Color(0xFF31E981);

enum GroceryPlannerView { week, recipes, selected, shopping }

class GroceryMealPlanner extends StatefulWidget {
  const GroceryMealPlanner({
    required this.products,
    required this.onFindProduct,
    super.key,
  });

  final List<GroceryProduct> products;
  final ValueChanged<String> onFindProduct;

  @override
  State<GroceryMealPlanner> createState() => _GroceryMealPlannerState();
}

class _GroceryMealPlannerState extends State<GroceryMealPlanner> {
  final _repository = const GroceryRecipeRepository();
  final _priceMealPlan = const PriceGroceryMealPlan();
  final _suggestBudgetPlan = const SuggestBudgetKetoPlan();

  GroceryRecipeData? _data;
  GroceryMealPlan? _plan;
  GroceryMealPlan? _suggestedPlan;
  int _budgetVariation = 0;
  int _mealVariation = 0;
  GroceryPlannerView _view = GroceryPlannerView.week;
  int _people = 1;
  Set<String> _checkedItems = {};
  String _recipeQuery = '';
  String? _recipeSection;
  Map<String, int> _selectedRecipes = {};
  final Map<String, GroceryRecipePrice> _recipePriceCache = {};
  int _productPriceSignature = 0;
  int _visibleRecipeCount = 12;
  String? _error;

  @override
  void initState() {
    super.initState();
    _productPriceSignature = _priceSignature(widget.products);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant GroceryMealPlanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _priceSignature(widget.products);
    if (signature == _productPriceSignature) return;
    _productPriceSignature = signature;
    _recipePriceCache.clear();
  }

  Future<void> _load() async {
    try {
      final data = await _repository.load();
      final prefs = await SharedPreferences.getInstance();
      final planId = prefs.getString('grocery_meal_plan_v1');
      final people = prefs.getInt('grocery_meal_people_v1') ?? 1;
      final checked =
          prefs.getStringList('grocery_shopping_checked_v1') ?? const [];
      final selected =
          prefs.getStringList('grocery_selected_recipes_v1') ?? const [];
      final recipeIds = data.recipes.map((recipe) => recipe.id).toSet();
      final plan = data.plans.firstWhere(
        (item) => item.id == planId,
        orElse: () => data.plans.firstWhere(
          (item) => item.id == 'budget_keto_80',
          orElse: () => data.plans.first,
        ),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _plan = plan;
        _people = plan.budgetNzd != null ? 1 : people.clamp(1, 6);
        _checkedItems = checked.toSet();
        _selectedRecipes = {
          for (final value in selected)
            if (value.split('=').length == 2 &&
                recipeIds.contains(value.split('=').first))
              value.split('=').first: int.tryParse(value.split('=').last) ?? 1,
        };
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'The weekly recipe data could not be loaded.');
    }
  }

  Future<void> _selectPlan(GroceryMealPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grocery_meal_plan_v1', plan.id);
    if (plan.budgetNzd != null) {
      await prefs.setInt('grocery_meal_people_v1', 1);
    }
    await prefs.remove('grocery_shopping_checked_v1');
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _suggestedPlan = null;
      if (plan.budgetNzd != null) _people = 1;
      _checkedItems = {};
    });
  }

  void _shuffleBudgetPlan() {
    final data = _data;
    final plan = _plan;
    if (data == null || plan == null || plan.id != 'budget_keto_80') return;
    final variation = ++_budgetVariation;
    final suggestion = _suggestBudgetPlan(
      data: data,
      basePlan: plan,
      products: widget.products,
      variation: variation,
    );
    if (!mounted) return;
    setState(() {
      _suggestedPlan = suggestion;
      _checkedItems = {};
    });
  }

  void _swapMeal(int dayIndex, String meal) {
    final data = _data;
    final selectedPlan = _plan;
    if (data == null || selectedPlan == null) return;
    final activePlan = _suggestedPlan ?? selectedPlan;
    final replacement = _suggestBudgetPlan.replaceMeal(
      data: data,
      plan: activePlan,
      products: widget.products,
      dayIndex: dayIndex,
      meal: meal,
      variation: ++_mealVariation,
    );
    if (identical(replacement, activePlan)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other priced keto $meal fits this plan.')),
      );
      return;
    }
    setState(() {
      _suggestedPlan = replacement;
      _checkedItems = {};
    });
  }

  Future<void> _setPeople(int people) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('grocery_meal_people_v1', people);
    await prefs.remove('grocery_shopping_checked_v1');
    if (!mounted) return;
    setState(() {
      _people = people;
      _checkedItems = {};
    });
  }

  Future<void> _toggleChecked(String id, bool checked) async {
    setState(() {
      checked ? _checkedItems.add(id) : _checkedItems.remove(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'grocery_shopping_checked_v1',
      _checkedItems.toList(),
    );
  }

  Future<void> _setSelectedRecipe(GroceryRecipe recipe, int servings) async {
    setState(() {
      if (servings <= 0) {
        _selectedRecipes.remove(recipe.id);
      } else {
        _selectedRecipes[recipe.id] = servings.clamp(1, 20);
      }
      _checkedItems = {};
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('grocery_selected_recipes_v1', [
      for (final selection in _selectedRecipes.entries)
        '${selection.key}=${selection.value}',
    ]);
    await prefs.remove('grocery_shopping_checked_v1');
  }

  GroceryRecipePrice _priceRecipe(GroceryRecipe recipe, {int people = 1}) {
    final key = '${recipe.id}:$people:$_productPriceSignature';
    return _recipePriceCache.putIfAbsent(
      key,
      () => _priceMealPlan.priceRecipe(
        recipe: recipe,
        people: people,
        products: widget.products,
      ),
    );
  }

  int _priceSignature(List<GroceryProduct> products) {
    return Object.hashAll([
      products.length,
      for (final product in products)
        Object.hash(product.id, product.currentPrice, product.lastChecked),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final plan = _plan;
    if (_error case final error?) {
      return Center(child: Text(error));
    }
    if (data == null || plan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activePlan = plan.id == 'budget_keto_80'
        ? _suggestedPlan ?? plan
        : plan;
    final shopping = buildWeeklyShoppingList(
      data: data,
      plan: activePlan,
      people: _people,
    );
    final weekPrice = _priceMealPlan.priceWeek(
      data: data,
      plan: activePlan,
      people: _people,
      products: widget.products,
    );
    final selectedShopping = buildSelectedRecipeShoppingList(
      data: data,
      selectedServings: _selectedRecipes,
    );
    final selectedPrices = _priceMealPlan.priceShoppingList(
      items: selectedShopping,
      products: widget.products,
    );
    final selectedPriceMap = {
      for (final price in selectedPrices) price.ingredient.id: price,
    };
    final selectedCheckoutTotal = selectedPrices.fold<double>(
      0,
      (total, price) => total + (price.purchaseCost ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _PlannerControls(
          data: data,
          plan: activePlan,
          selectedPlan: plan,
          people: _people,
          view: _view,
          onPlanChanged: _selectPlan,
          onPeopleChanged: _setPeople,
          onViewChanged: (view) => setState(() => _view = view),
          onShuffle: plan.id == 'budget_keto_80' ? _shuffleBudgetPlan : null,
          weekPrice: weekPrice,
          selectedCount: _selectedRecipes.length,
        ),
        const SizedBox(height: 14),
        if (_view == GroceryPlannerView.week)
          for (var index = 0; index < activePlan.days.length; index++) ...[
            _DayCard(
              dayIndex: index,
              day: activePlan.days[index],
              data: data,
              price: weekPrice.days[index],
              people: _people,
              onRecipeTap: (recipe) => _showRecipe(recipe),
              onSwapMeal: _swapMeal,
            ),
            const SizedBox(height: 12),
          ]
        else if (_view == GroceryPlannerView.recipes)
          _RecipeLibrary(
            recipes: data.recipes
                .where((recipe) => recipe.cookbookId == 'rm_200')
                .toList(),
            query: _recipeQuery,
            section: _recipeSection,
            onQueryChanged: (value) {
              setState(() {
                _recipeQuery = value.trim().toLowerCase();
                _visibleRecipeCount = 12;
              });
            },
            onSectionChanged: (value) {
              setState(() {
                _recipeSection = value;
                _visibleRecipeCount = 12;
              });
            },
            onRecipeTap: _showRecipe,
            priceForRecipe: _priceRecipe,
            selectedServings: _selectedRecipes,
            onSelectedChanged: _setSelectedRecipe,
            visibleCount: _visibleRecipeCount,
            onLoadMore: () {
              setState(() => _visibleRecipeCount += 12);
            },
          )
        else if (_view == GroceryPlannerView.selected)
          _SelectedMeals(
            data: data,
            selectedServings: _selectedRecipes,
            priceForRecipe: (recipe, servings) =>
                _priceRecipe(recipe, people: servings),
            onSelectedChanged: _setSelectedRecipe,
            shoppingList: _ShoppingList(
              items: selectedShopping,
              checkedItems: _checkedItems,
              onChecked: _toggleChecked,
              onFindProduct: widget.onFindProduct,
              onOpenProduct: _openProduct,
              onSearchWebsite: _openIngredientSearch,
              prices: selectedPriceMap,
              onShare: () => _shareSelectedShoppingList(
                data,
                selectedShopping,
                selectedPriceMap,
              ),
              checkoutTotal: selectedCheckoutTotal,
            ),
          )
        else
          _ShoppingList(
            items: shopping,
            checkedItems: _checkedItems,
            onChecked: _toggleChecked,
            onFindProduct: widget.onFindProduct,
            onOpenProduct: _openProduct,
            onSearchWebsite: _openIngredientSearch,
            prices: {
              for (final item in weekPrice.shoppingItems)
                item.ingredient.id: item,
            },
            onShare: () => _shareShoppingList(activePlan, shopping, {
              for (final item in weekPrice.shoppingItems)
                item.ingredient.id: item,
            }),
            checkoutTotal: weekPrice.checkoutTotal,
          ),
      ],
    );
  }

  Future<void> _showRecipe(GroceryRecipe recipe) {
    final price = _priceRecipe(recipe, people: _people);
    final cookbook = _data?.cookbook(recipe.cookbookId);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              recipe.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${recipe.minutes} minutes • ${recipe.diets.join(' + ')}',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 8),
            Text(
              price.isComplete
                  ? 'Estimated stocked ingredients '
                        '${formatPrice(price.total)} total • '
                        '${formatPrice(price.perServing)} per serving'
                  : 'Incomplete stock match • known items '
                        '${formatPrice(price.total)} • '
                        'unavailable ingredients are not priced',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (recipe.supermarketAdapted) ...[
              const SizedBox(height: 8),
              const Text(
                'NZ supermarket version • keto-safe ingredient names and '
                'substitutions are used for pricing.',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (cookbook != null) ...[
              const SizedBox(height: 8),
              Text(
                'Cookbook inspiration: ${cookbook.title} — '
                '${cookbook.author}'
                '${recipe.sourcePage == null ? '' : ', page ${recipe.sourcePage}'}. '
                '${cookbook.note}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
            if (recipe.calories != null ||
                recipe.proteinGrams != null ||
                recipe.netCarbsGrams != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (recipe.calories case final calories?)
                    '${_cleanNumber(calories)} kcal',
                  if (recipe.proteinGrams case final protein?)
                    '${_cleanNumber(protein)} g protein',
                  if (recipe.netCarbsGrams case final carbs?)
                    '${_cleanNumber(carbs)} g net carbs',
                ].join(' • '),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Ingredients',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if (recipe.ingredients.isNotEmpty)
              for (var index = 0; index < recipe.ingredients.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(recipe.ingredients[index].name),
                  subtitle: Text(
                    [
                      ?recipe.ingredients[index].adaptationNote,
                      ?price.ingredients[index].substitutionLabel,
                      if (recipe.ingredients[index].pantryStaple)
                        'Pantry staple • excluded from live price'
                      else if (price.ingredients[index].product == null)
                        'Catalogue reviewed • no keto-safe substitute found'
                      else
                        '${price.ingredients[index].closestMatch ? 'Closest match • ' : ''}'
                            '${price.ingredients[index].product!.store.label}: '
                            '${price.ingredients[index].product!.name} • '
                            '${formatPrice(price.ingredients[index].product!.currentPrice)} per package',
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${formatShoppingAmount(recipe.ingredients[index].amount * _people, recipe.ingredients[index].unit)}\n${formatOptionalPrice(price.ingredients[index].usedCost)}',
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new, size: 18),
                    ],
                  ),
                  onTap: recipe.ingredients[index].pantryStaple
                      ? null
                      : price.ingredients[index].product == null
                      ? () => _openIngredientSearch(
                          recipe.ingredients[index].name,
                        )
                      : () => _openProduct(price.ingredients[index].product!),
                )
            else
              for (final ingredient in recipe.sourceIngredients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('• $ingredient'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openIngredientSearch(ingredient),
                ),
            const SizedBox(height: 12),
            if (recipe.steps.isNotEmpty) ...[
              const Text(
                'Method',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < recipe.steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('${index + 1}. ${recipe.steps[index]}'),
                ),
            ] else ...[
              const Text(
                'Method',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'See page ${recipe.sourcePage} in RM-200-Recipe-Book.pdf '
                'for the complete method.',
                style: const TextStyle(color: _muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _shareShoppingList(
    GroceryMealPlan plan,
    List<GroceryShoppingItem> items,
    Map<String, GroceryIngredientPrice> prices,
  ) async {
    final lines = [
      '${plan.name} shopping list for $_people '
          '${_people == 1 ? 'person' : 'people'}',
      '',
      for (final item in items) ...[
        '${_checkedItems.contains(item.id) ? '✓' : '□'} '
            '${item.name}: ${formatShoppingAmount(item.amount, item.unit)}'
            '${prices[item.id]?.purchaseCost == null ? '' : ' - ${formatPrice(prices[item.id]!.purchaseCost!)}'}',
        if (prices[item.id]?.product case final product?)
          '${product.store.label}: ${product.name} ${product.size} '
              '${product.sourceUrl}',
      ],
      '',
      'Check product labels and adjust quantities for appetite and leftovers.',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _shareSelectedShoppingList(
    GroceryRecipeData data,
    List<GroceryShoppingItem> items,
    Map<String, GroceryIngredientPrice> prices,
  ) async {
    final lines = [
      'Selected meals',
      for (final selection in _selectedRecipes.entries)
        '${selection.value} serving${selection.value == 1 ? '' : 's'} - '
            '${data.recipe(selection.key).name}',
      '',
      'Shopping list',
      for (final item in items) ...[
        '${_checkedItems.contains(item.id) ? '✓' : '□'} '
            '${item.name}: ${formatShoppingAmount(item.amount, item.unit)}'
            '${prices[item.id]?.purchaseCost == null ? '' : ' - ${formatPrice(prices[item.id]!.purchaseCost!)}'}',
        if (prices[item.id]?.product case final product?)
          '${product.store.label}: ${product.name} ${product.size} '
              '${product.sourceUrl}',
      ],
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _openProduct(GroceryProduct product) async {
    final sourceUrl = product.sourceUrl.trim();
    if (sourceUrl.isNotEmpty) {
      await launchUrl(
        Uri.parse(sourceUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    await _openIngredientSearch(product.name, store: product.store);
  }

  Future<void> _openIngredientSearch(
    String ingredient, {
    GroceryStore store = GroceryStore.paknsave,
  }) async {
    final query = Uri.encodeQueryComponent(
      ingredient
          .replaceAll(RegExp(r'^[•\s]+'), '')
          .replaceAll(RegExp(r'^\d+(?:[./\s]\d+)?\s*\w*\.?\s*'), '')
          .trim(),
    );
    final url = switch (store) {
      GroceryStore.woolworths =>
        'https://www.woolworths.co.nz/shop/searchproducts?search=$query',
      GroceryStore.newWorld =>
        'https://www.newworld.co.nz/shop/Search?q=$query',
      GroceryStore.any || GroceryStore.paknsave =>
        'https://www.paknsave.co.nz/shop/Search?q=$query',
    };
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _PlannerControls extends StatelessWidget {
  const _PlannerControls({
    required this.data,
    required this.plan,
    required this.selectedPlan,
    required this.people,
    required this.view,
    required this.onPlanChanged,
    required this.onPeopleChanged,
    required this.onViewChanged,
    required this.onShuffle,
    required this.weekPrice,
    required this.selectedCount,
  });

  final GroceryRecipeData data;
  final GroceryMealPlan plan;
  final GroceryMealPlan selectedPlan;
  final int people;
  final GroceryPlannerView view;
  final ValueChanged<GroceryMealPlan> onPlanChanged;
  final ValueChanged<int> onPeopleChanged;
  final ValueChanged<GroceryPlannerView> onViewChanged;
  final VoidCallback? onShuffle;
  final GroceryWeekPrice weekPrice;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly meal plan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Seven days of simple meals with one combined shopping list.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          if (plan.profile.isNotEmpty) ...[
            Text(
              plan.profile,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (plan.note.isNotEmpty) ...[
            Text(
              plan.note,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                'Meals used: ${formatPrice(weekPrice.mealUsageTotal)}',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Estimated checkout: ${formatPrice(weekPrice.checkoutTotal)}',
                style: TextStyle(
                  color:
                      plan.budgetNzd == null ||
                          weekPrice.checkoutTotal <= plan.budgetNzd!
                      ? _green
                      : Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (plan.budgetNzd case final budget?)
                Text(
                  weekPrice.checkoutTotal <= budget
                      ? '${formatPrice(budget - weekPrice.checkoutTotal)} '
                            'under budget'
                      : '${formatPrice(weekPrice.checkoutTotal - budget)} '
                            'over budget',
                  style: TextStyle(
                    color: weekPrice.checkoutTotal <= budget
                        ? _green
                        : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<GroceryMealPlan>(
                value: selectedPlan,
                onChanged: (value) {
                  if (value != null) onPlanChanged(value);
                },
                items: [
                  for (final item in data.plans)
                    DropdownMenuItem(value: item, child: Text(item.name)),
                ],
              ),
              DropdownButton<int>(
                value: people,
                onChanged: plan.budgetNzd != null
                    ? null
                    : (value) {
                        if (value != null) onPeopleChanged(value);
                      },
                items: [
                  for (var value = 1; value <= 6; value++)
                    DropdownMenuItem(
                      value: value,
                      child: Text('$value ${value == 1 ? 'person' : 'people'}'),
                    ),
                ],
              ),
              if (onShuffle != null)
                FilledButton.icon(
                  onPressed: onShuffle,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle menu'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<GroceryPlannerView>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: GroceryPlannerView.week,
                  icon: Icon(Icons.calendar_view_week_outlined),
                  label: Text('Plan'),
                ),
                const ButtonSegment(
                  value: GroceryPlannerView.recipes,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Recipes'),
                ),
                ButtonSegment(
                  value: GroceryPlannerView.selected,
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  label: Text('My meals ($selectedCount)'),
                ),
                const ButtonSegment(
                  value: GroceryPlannerView.shopping,
                  icon: Icon(Icons.shopping_cart_outlined),
                  label: Text('Shopping list'),
                ),
              ],
              selected: {view},
              onSelectionChanged: (values) => onViewChanged(values.first),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Quantities are a starting point. Check ingredients, allergies, '
            'medical advice, appetite, and leftovers.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayIndex,
    required this.day,
    required this.data,
    required this.onRecipeTap,
    required this.price,
    required this.people,
    required this.onSwapMeal,
  });

  final int dayIndex;
  final GroceryMealDay day;
  final GroceryRecipeData data;
  final ValueChanged<GroceryRecipe> onRecipeTap;
  final GroceryDayPrice price;
  final int people;
  final void Function(int dayIndex, String meal) onSwapMeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.day,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            price.isComplete
                ? 'Estimated ${formatPrice(price.total)} for $people '
                      '${people == 1 ? 'person' : 'people'}'
                : 'Known meal cost ${formatPrice(price.total)} • '
                      'some catalogue prices unavailable',
            style: TextStyle(
              color: price.isComplete ? _green : Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _MealRow(
            label: 'Breakfast',
            recipe: data.recipe(day.breakfastId),
            onTap: onRecipeTap,
            price: price.breakfast,
            onSwap: () => onSwapMeal(dayIndex, 'Breakfast'),
          ),
          _MealRow(
            label: 'Lunch',
            recipe: data.recipe(day.lunchId),
            onTap: onRecipeTap,
            price: price.lunch,
            onSwap: () => onSwapMeal(dayIndex, 'Lunch'),
          ),
          _MealRow(
            label: 'Dinner',
            recipe: data.recipe(day.dinnerId),
            onTap: onRecipeTap,
            price: price.dinner,
            onSwap: () => onSwapMeal(dayIndex, 'Dinner'),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.label,
    required this.recipe,
    required this.onTap,
    required this.price,
    required this.onSwap,
  });

  final String label;
  final GroceryRecipe recipe;
  final ValueChanged<GroceryRecipe> onTap;
  final GroceryRecipePrice price;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: SizedBox(
        width: 72,
        child: Text(label, style: const TextStyle(color: _muted)),
      ),
      title: Text(
        recipe.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        price.isComplete
            ? 'Estimated ${formatPrice(price.total)}'
            : price.total > 0
            ? '${formatPrice(price.total)} known • price incomplete'
            : 'Catalogue price unavailable',
        style: TextStyle(
          color: price.isComplete ? _green : Colors.orangeAccent,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Try another keto $label',
            onPressed: onSwap,
            icon: const Icon(Icons.shuffle, color: _blue),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => onTap(recipe),
    );
  }
}

class _RecipeLibrary extends StatelessWidget {
  const _RecipeLibrary({
    required this.recipes,
    required this.query,
    required this.section,
    required this.onQueryChanged,
    required this.onSectionChanged,
    required this.onRecipeTap,
    required this.priceForRecipe,
    required this.selectedServings,
    required this.onSelectedChanged,
    required this.visibleCount,
    required this.onLoadMore,
  });

  final List<GroceryRecipe> recipes;
  final String query;
  final String? section;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<GroceryRecipe> onRecipeTap;
  final GroceryRecipePrice Function(GroceryRecipe recipe) priceForRecipe;
  final Map<String, int> selectedServings;
  final void Function(GroceryRecipe recipe, int servings) onSelectedChanged;
  final int visibleCount;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final sections = {
      for (final recipe in recipes)
        if (recipe.section.isNotEmpty) recipe.section,
    }.toList()..sort();
    final filtered =
        recipes.where((recipe) {
          final matchesSection = section == null || recipe.section == section;
          final text =
              '${recipe.name} ${recipe.section} ${recipe.sourceIngredients.join(' ')}'
                  .toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              query
                  .split(RegExp(r'\s+'))
                  .where((term) => term.isNotEmpty)
                  .every(text.contains);
          return matchesSection && matchesQuery;
        }).toList()..sort((left, right) {
          final page = (left.sourcePage ?? 0).compareTo(right.sourcePage ?? 0);
          return page != 0 ? page : left.name.compareTo(right.name);
        });
    final visible = filtered.take(visibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            labelText: 'Search all cookbook recipes',
            hintText: 'Chicken, bacon, breakfast, broccoli...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          initialValue: section,
          decoration: const InputDecoration(labelText: 'Cookbook section'),
          onChanged: onSectionChanged,
          items: [
            const DropdownMenuItem(value: null, child: Text('All sections')),
            for (final value in sections)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${filtered.length} of ${recipes.length} recipes',
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final recipe in visible) ...[
          _RecipeSelectionCard(
            recipe: recipe,
            price: priceForRecipe(recipe),
            selectedServings: selectedServings[recipe.id] ?? 0,
            onTap: () => onRecipeTap(recipe),
            onSelectedChanged: (servings) =>
                onSelectedChanged(recipe, servings),
          ),
          const SizedBox(height: 6),
        ],
        if (visible.length < filtered.length)
          OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more),
            label: Text(
              'Load 12 more '
              '(${filtered.length - visible.length} remaining)',
            ),
          ),
      ],
    );
  }
}

class _RecipeSelectionCard extends StatelessWidget {
  const _RecipeSelectionCard({
    required this.recipe,
    required this.price,
    required this.selectedServings,
    required this.onTap,
    required this.onSelectedChanged,
  });

  final GroceryRecipe recipe;
  final GroceryRecipePrice price;
  final int selectedServings;
  final VoidCallback onTap;
  final ValueChanged<int> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: CircleAvatar(
              child: Text(recipe.sourcePage?.toString() ?? '?'),
            ),
            title: Text(
              recipe.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              [
                recipe.section,
                price.isComplete
                    ? '${formatPrice(price.perServing)} per serving'
                    : 'Incomplete • ${formatPrice(price.perServing)} known',
                if (recipe.proteinGrams case final protein?)
                  '${_cleanNumber(protein)} g protein',
              ].join(' • '),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedServings == 0
                        ? 'Not in your meal list'
                        : '$selectedServings serving'
                              '${selectedServings == 1 ? '' : 's'} selected',
                    style: TextStyle(
                      color: selectedServings == 0 ? _muted : _green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove one serving',
                  onPressed: selectedServings == 0
                      ? null
                      : () => onSelectedChanged(selectedServings - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: 'Add one serving',
                  onPressed: () => onSelectedChanged(selectedServings + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMeals extends StatelessWidget {
  const _SelectedMeals({
    required this.data,
    required this.selectedServings,
    required this.priceForRecipe,
    required this.onSelectedChanged,
    required this.shoppingList,
  });

  final GroceryRecipeData data;
  final Map<String, int> selectedServings;
  final GroceryRecipePrice Function(GroceryRecipe recipe, int servings)
  priceForRecipe;
  final void Function(GroceryRecipe recipe, int servings) onSelectedChanged;
  final Widget shoppingList;

  @override
  Widget build(BuildContext context) {
    if (selectedServings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.playlist_add, size: 42, color: _muted),
              SizedBox(height: 10),
              Text(
                'Select recipes and servings from the Recipes tab.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final selections = [
      for (final selection in selectedServings.entries)
        (
          recipe: data.recipe(selection.key),
          servings: selection.value,
          price: priceForRecipe(data.recipe(selection.key), selection.value),
        ),
    ];
    final mealCost = selections.fold<double>(
      0,
      (total, selection) => total + selection.price.total,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${selections.length} selected meal'
              '${selections.length == 1 ? '' : 's'} • '
              'ingredient-use cost ${formatPrice(mealCost)}',
              style: const TextStyle(
                color: _green,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final selection in selections) ...[
          Card(
            child: ListTile(
              title: Text(
                selection.recipe.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${selection.servings} serving'
                '${selection.servings == 1 ? '' : 's'} • '
                '${formatPrice(selection.price.total)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => onSelectedChanged(
                      selection.recipe,
                      selection.servings - 1,
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    onPressed: () => onSelectedChanged(
                      selection.recipe,
                      selection.servings + 1,
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 12),
        const Text(
          'Shopping list for selected meals',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        shoppingList,
      ],
    );
  }
}

class _ShoppingList extends StatelessWidget {
  const _ShoppingList({
    required this.items,
    required this.checkedItems,
    required this.onChecked,
    required this.onFindProduct,
    required this.onOpenProduct,
    required this.onSearchWebsite,
    required this.onShare,
    required this.prices,
    required this.checkoutTotal,
  });

  final List<GroceryShoppingItem> items;
  final Set<String> checkedItems;
  final void Function(String id, bool checked) onChecked;
  final ValueChanged<String> onFindProduct;
  final ValueChanged<GroceryProduct> onOpenProduct;
  final ValueChanged<String> onSearchWebsite;
  final VoidCallback onShare;
  final Map<String, GroceryIngredientPrice> prices;
  final double checkoutTotal;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<GroceryShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share shopping list'),
        ),
        const SizedBox(height: 8),
        Text(
          'Estimated checkout total: ${formatPrice(checkoutTotal)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _green,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        for (final group in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(
              group.key,
              style: const TextStyle(
                color: _blue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final item in group.value) ...[
            _ShoppingItemCard(
              item: item,
              price: prices[item.id],
              checked: checkedItems.contains(item.id),
              onChecked: (value) => onChecked(item.id, value),
              onFindProduct: () => onFindProduct(item.name),
              onOpenProduct: onOpenProduct,
              onSearchWebsite: () => onSearchWebsite(item.name),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({
    required this.item,
    required this.price,
    required this.checked,
    required this.onChecked,
    required this.onFindProduct,
    required this.onOpenProduct,
    required this.onSearchWebsite,
  });

  final GroceryShoppingItem item;
  final GroceryIngredientPrice? price;
  final bool checked;
  final ValueChanged<bool> onChecked;
  final VoidCallback onFindProduct;
  final ValueChanged<GroceryProduct> onOpenProduct;
  final VoidCallback onSearchWebsite;

  @override
  Widget build(BuildContext context) {
    final product = price?.product;
    final packageCount = price?.packageCount;
    return Card(
      child: Column(
        children: [
          CheckboxListTile(
            value: checked,
            onChanged: (value) => onChecked(value ?? false),
            title: Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '${formatShoppingAmount(item.amount, item.unit)}'
              ' • ${formatOptionalPrice(price?.purchaseCost)}',
            ),
            activeColor: _green,
          ),
          if (product != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(product.name),
              subtitle: Text(
                '${product.store.label} • ${product.size} • '
                '${formatPrice(product.currentPrice)} each'
                '${packageCount == null ? '' : ' • $packageCount package${packageCount == 1 ? '' : 's'}'}',
              ),
              trailing: FilledButton.tonalIcon(
                onPressed: () => onOpenProduct(product),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('View item'),
              ),
            )
          else
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onFindProduct,
                  icon: const Icon(Icons.price_check_outlined),
                  label: const Text('Find in app'),
                ),
                TextButton.icon(
                  onPressed: onSearchWebsite,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Search store'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String formatShoppingAmount(double amount, String unit) {
  if (unit == 'each') {
    final rounded = amount.ceil();
    return '$rounded ${rounded == 1 ? 'item' : 'items'}';
  }
  if (unit == 'g' && amount >= 1000) {
    return '${_cleanNumber(amount / 1000)} kg';
  }
  if (unit == 'ml' && amount >= 1000) {
    return '${_cleanNumber(amount / 1000)} L';
  }
  return '${_cleanNumber(amount)} $unit';
}

String formatPrice(double value) => '\$${value.toStringAsFixed(2)}';

String formatOptionalPrice(double? value) {
  return value == null ? 'Price unavailable' : formatPrice(value);
}

String _cleanNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

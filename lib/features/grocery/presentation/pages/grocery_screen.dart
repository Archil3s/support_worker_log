import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/grocery_product.dart';
import '../controllers/grocery_controller.dart';
import '../widgets/grocery_meal_planner.dart';
import '../widgets/grocery_price_history_sheet.dart';
import '../widgets/grocery_product_card.dart';

const _panel = Color(0xFF151B29);
const _border = Color(0xFF34405F);
const _muted = Color(0xFF8396C7);

enum _GroceryView { prices, mealPlan }

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  final _controller = GroceryController();
  final _searchController = TextEditingController();
  _GroceryView _view = _GroceryView.prices;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    unawaited(_controller.initialise());
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_controller.load(showLoading: false));
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final products = _controller.products;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_GroceryView>(
              segments: const [
                ButtonSegment(
                  value: _GroceryView.prices,
                  icon: Icon(Icons.price_check_outlined),
                  label: Text('Prices'),
                ),
                ButtonSegment(
                  value: _GroceryView.mealPlan,
                  icon: Icon(Icons.restaurant_menu_outlined),
                  label: Text('Meal plan & list'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (values) {
                setState(() => _view = values.first);
              },
            ),
          ),
        ),
        Expanded(
          child: _view == _GroceryView.mealPlan
              ? GroceryMealPlanner(
                  products: _controller.catalogue,
                  onFindProduct: _findProduct,
                )
              : _priceFinder(products),
        ),
      ],
    );
  }

  Widget _priceFinder(List<GroceryProduct> products) {
    return RefreshIndicator(
      onRefresh: _controller.refreshPrices,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            sliver: SliverToBoxAdapter(
              child: _SearchPanel(
                controller: _searchController,
                groceryController: _controller,
                onSearch: () => _controller.search(_searchController.text),
              ),
            ),
          ),
          if (_controller.loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_controller.error case final error?)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MessageState(
                icon: Icons.search_off_rounded,
                title: error,
                actionLabel: 'Retry',
                onAction: _controller.initialise,
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${products.length} ordinary product'
                  '${products.length == 1 ? '' : 's'} compatible with '
                  '${_controller.diet.label.toLowerCase()}'
                  '${_controller.query.isEmpty ? '' : ' matching "${_controller.query}"'}',
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = products[index];
                  return GroceryProductCard(
                    product: product,
                    onTap: () => _showHistory(product),
                  );
                }, childCount: products.length),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 265,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _findProduct(String productName) {
    _searchController.text = productName;
    _controller.search(productName);
    setState(() => _view = _GroceryView.prices);
  }

  Future<void> _showHistory(GroceryProduct product) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      constraints: const BoxConstraints(maxWidth: 700),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: GroceryPriceHistorySheet(product: product),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.groceryController,
    required this.onSearch,
  });

  final TextEditingController controller;
  final GroceryController groceryController;
  final VoidCallback onSearch;

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
            'Carnivore and keto price finder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live prices from ${groceryController.locationLabel} stores. '
            'Products marketed as keto or carnivore are excluded.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('grocery-search-field'),
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: groceryController.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              labelText: 'Filter compatible products',
              hintText: 'Steak, eggs, butter, avocado...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DropdownButton<GroceryDiet>(
                value: groceryController.diet,
                onChanged: (value) {
                  if (value != null) groceryController.setDiet(value);
                },
                items: [
                  for (final diet in GroceryDiet.values)
                    DropdownMenuItem(value: diet, child: Text(diet.label)),
                ],
              ),
              DropdownButton<GroceryStore>(
                value: groceryController.store,
                onChanged: (value) {
                  if (value != null) groceryController.setStore(value);
                },
                items: [
                  for (final store in GroceryStore.values)
                    DropdownMenuItem(value: store, child: Text(store.label)),
                ],
              ),
              DropdownButton<GrocerySort>(
                value: groceryController.sort,
                onChanged: (value) {
                  if (value != null) groceryController.setSort(value);
                },
                items: [
                  for (final sort in GrocerySort.values)
                    DropdownMenuItem(value: sort, child: Text(sort.label)),
                ],
              ),
              DropdownButton<double>(
                value: groceryController.minimumProteinPer100Grams ?? 0,
                onChanged: (value) {
                  groceryController.setMinimumProteinPer100Grams(
                    value == 0 ? null : value,
                  );
                },
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Any protein level')),
                  DropdownMenuItem(
                    value: 15,
                    child: Text('15+ g protein / 100 g'),
                  ),
                  DropdownMenuItem(
                    value: 20,
                    child: Text('20+ g protein / 100 g'),
                  ),
                  DropdownMenuItem(
                    value: 25,
                    child: Text('25+ g protein / 100 g'),
                  ),
                  DropdownMenuItem(
                    value: 30,
                    child: Text('30+ g protein / 100 g'),
                  ),
                ],
              ),
              DropdownButton<double>(
                value: groceryController.maximumPricePerKilogram ?? 0,
                onChanged: (value) {
                  groceryController.setMaximumPricePerKilogram(
                    value == 0 ? null : value,
                  );
                },
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Any price / kg')),
                  DropdownMenuItem(value: 10, child: Text(r'Under $10 / kg')),
                  DropdownMenuItem(value: 15, child: Text(r'Under $15 / kg')),
                  DropdownMenuItem(value: 20, child: Text(r'Under $20 / kg')),
                  DropdownMenuItem(value: 25, child: Text(r'Under $25 / kg')),
                  DropdownMenuItem(value: 30, child: Text(r'Under $30 / kg')),
                ],
              ),
              if (groceryController.categories.isNotEmpty)
                DropdownButton<String?>(
                  value: groceryController.category,
                  hint: const Text('All categories'),
                  onChanged: groceryController.setCategory,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All categories'),
                    ),
                    for (final category in groceryController.categories)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.replaceAll('-', ' ')),
                      ),
                  ],
                ),
              FilterChip(
                selected: groceryController.currentOnly,
                onSelected: (value) {
                  unawaited(groceryController.setCurrentOnly(value));
                },
                label: const Text('Checked in last 14 days'),
              ),
              ActionChip(
                avatar: const Icon(Icons.refresh, size: 18),
                onPressed:
                    groceryController.loading || groceryController.scraping
                    ? null
                    : groceryController.refreshPrices,
                label: Text(
                  groceryController.scraping
                      ? 'Scraping ${groceryController.pagesCompleted}/'
                            '${groceryController.pagesTotal}'
                      : 'Scrape prices now',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            groceryController.lastUpdated == null
                ? groceryController.scraping
                      ? 'First local scrape is running: '
                            '${groceryController.pagesCompleted}/'
                            '${groceryController.pagesTotal} pages.'
                      : 'No local prices saved yet.'
                : 'Updated ${DateFormat('d MMM, h:mm a').format(groceryController.lastUpdated!)} for ${groceryController.locationLabel}. Local scraper refreshes every 6 hours.',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (groceryController.warning case final warning?) ...[
            Text(
              warning.split('\n').first,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
            const SizedBox(height: 6),
          ],
          const Text(
            'Compatibility is estimated from product names and categories. '
            'Check the ingredient label before buying.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

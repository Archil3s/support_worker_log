import 'package:flutter/material.dart';

import '../../domain/entities/grocery_product.dart';
import '../../domain/entities/grocery_recipe.dart';
import '../../domain/usecases/price_grocery_meal_plan.dart';
import 'grocery_formatters.dart';

const _blue = Color(0xFF4F8DF7);
const _green = Color(0xFF31E981);

class GroceryShoppingList extends StatelessWidget {
  const GroceryShoppingList({
    required this.items,
    required this.checkedItems,
    required this.onChecked,
    required this.onFindProduct,
    required this.onOpenProduct,
    required this.onSearchWebsite,
    required this.onShare,
    required this.prices,
    required this.checkoutTotal,
    super.key,
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

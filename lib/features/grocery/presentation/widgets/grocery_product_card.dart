import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/grocery_product.dart';

class GroceryProductCard extends StatelessWidget {
  const GroceryProductCard({
    required this.product,
    required this.onTap,
    super.key,
  });

  final GroceryProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = product.priceChangePercent;
    final changeColor = change == null || change == 0
        ? const Color(0xFF8396C7)
        : change < 0
        ? const Color(0xFF31E981)
        : const Color(0xFFFF7A7A);
    final checked = product.lastChecked;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StoreBadge(store: product.store),
                  const Spacer(),
                  if (change != null)
                    Text(
                      '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                product.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (product.size.isNotEmpty) product.size,
                  if (product.category.isNotEmpty)
                    product.category.replaceAll('-', ' '),
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8396C7)),
              ),
              const SizedBox(height: 8),
              Text(
                product.compatibilityLabel,
                style: const TextStyle(
                  color: Color(0xFF4F8DF7),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (product.estimatedProteinGramsPerDollar case final value?) ...[
                const SizedBox(height: 5),
                Text(
                  'Estimated ${value.toStringAsFixed(1)} g protein per \$1'
                  '${product.pricePerKilogram == null ? '' : ' • ${NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(product.pricePerKilogram)}/kg'}',
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(
                      symbol: r'$',
                      decimalDigits: 2,
                    ).format(product.currentPrice),
                    style: const TextStyle(
                      color: Color(0xFF31E981),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (product.unitPrice.isNotEmpty)
                    Flexible(
                      child: Text(
                        product.unitPrice,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFFB8C7EF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                checked == null
                    ? '${product.priceHistory.length} price record(s)'
                    : 'Checked ${DateFormat('d MMM yyyy').format(checked)}',
                style: const TextStyle(color: Color(0xFF8396C7), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  const _StoreBadge({required this.store});

  final GroceryStore store;

  @override
  Widget build(BuildContext context) {
    final color = switch (store) {
      GroceryStore.woolworths => const Color(0xFF62B446),
      GroceryStore.paknsave => const Color(0xFFFFD522),
      GroceryStore.newWorld => const Color(0xFFE53935),
      GroceryStore.any => const Color(0xFF4F8DF7),
    };
    final foreground = store == GroceryStore.paknsave
        ? Colors.black
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        store.label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

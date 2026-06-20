import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/grocery_product.dart';

class GroceryPriceHistorySheet extends StatelessWidget {
  const GroceryPriceHistorySheet({required this.product, super.key});

  final GroceryProduct product;

  @override
  Widget build(BuildContext context) {
    final points = product.priceHistory;
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF8396C7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              product.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${product.store.label} • ${product.size}',
              style: const TextStyle(color: Color(0xFF8396C7)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  currency.format(product.currentPrice),
                  style: const TextStyle(
                    color: Color(0xFF31E981),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 14),
                if (product.unitPrice.isNotEmpty)
                  Text(
                    product.unitPrice,
                    style: const TextStyle(
                      color: Color(0xFFB8C7EF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (points.length > 1) ...[
              const Text(
                'Price history',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(),
                      rightTitles: AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var index = 0; index < points.length; index++)
                            FlSpot(index.toDouble(), points[index].price),
                        ],
                        color: const Color(0xFF4F8DF7),
                        barWidth: 4,
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(
                            0xFF4F8DF7,
                          ).withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            for (final point in points.reversed.take(12))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  DateFormat('d MMM yyyy').format(point.date),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  currency.format(point.price),
                  style: const TextStyle(
                    color: Color(0xFFB8C7EF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openStoreSearch(product),
                icon: const Icon(Icons.open_in_new),
                label: Text('Open ${product.store.label} search'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openStoreSearch(GroceryProduct product) async {
  if (product.sourceUrl.isNotEmpty) {
    await launchUrl(
      Uri.parse(product.sourceUrl),
      mode: LaunchMode.externalApplication,
    );
    return;
  }
  final query = Uri.encodeQueryComponent(product.name);
  final url = switch (product.store) {
    GroceryStore.woolworths =>
      'https://www.woolworths.co.nz/shop/searchproducts?search=$query',
    GroceryStore.paknsave => 'https://www.paknsave.co.nz/shop/Search?q=$query',
    GroceryStore.newWorld => 'https://www.newworld.co.nz/shop/Search?q=$query',
    GroceryStore.any =>
      'https://www.google.com/search?q=${Uri.encodeQueryComponent('${product.name} NZ supermarket')}',
  };
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

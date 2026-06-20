import 'package:flutter_test/flutter_test.dart';
import 'package:support_worker_log/features/grocery/data/datasources/grocery_catalogue_decoder.dart';
import 'package:support_worker_log/features/grocery/domain/entities/grocery_product.dart';

void main() {
  test('parses the local scraper catalogue and price history', () {
    final catalogue = decodeGroceryCatalogue('''
      {
        "ok": true,
        "updatedAt": "2026-06-19T08:00:00Z",
        "location": {
          "city": "Blenheim",
          "region": "Marlborough",
          "country": "New Zealand"
        },
        "status": {
          "running": true,
          "pagesCompleted": 4,
          "pagesTotal": 40,
          "warning": "Woolworths Blenheim is temporarily unavailable."
        },
        "products": [
          {
            "id": "eggs-1",
            "name": "Free Range Eggs 12 Pack",
            "size": "12pk",
            "category": "eggs",
            "sourceSite": "newworld.co.nz",
            "sourceUrl": "https://www.newworld.co.nz/eggs-1",
            "lastChecked": "2026-06-19",
            "unitPrice": "",
            "priceHistory": [
              {"date": "2026-05-01", "price": 9.00},
              {"date": "2026-06-19", "price": 8.50}
            ]
          }
        ]
      }
    ''');

    expect(catalogue.products, hasLength(1));
    expect(catalogue.scraping, isTrue);
    expect(catalogue.pagesCompleted, 4);
    expect(catalogue.pagesTotal, 40);
    expect(catalogue.location.label, 'Blenheim, Marlborough');
    expect(catalogue.warning, contains('Woolworths Blenheim'));
    expect(catalogue.products.single.currentPrice, 8.5);
    expect(catalogue.products.single.store, GroceryStore.newWorld);
  });

  test('finds ordinary carnivore and keto products', () {
    final steak = GroceryProduct.fromJson({
      'id': 'steak',
      'name': 'Beef Scotch Fillet Steak 500g',
      'size': '500g',
      'category': 'beef-lamb',
      'sourceSite': 'paknsave.co.nz',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 15},
      ],
    });
    final avocado = GroceryProduct.fromJson({
      'id': 'avocado',
      'name': 'Fresh Avocado',
      'size': 'each',
      'category': 'fresh-vegetables',
      'sourceSite': 'newworld.co.nz',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 2},
      ],
    });
    final marketed = GroceryProduct.fromJson({
      'id': 'keto-bar',
      'name': 'Keto Protein Bar',
      'size': '50g',
      'category': 'other-snacks',
      'sourceSite': 'countdown.co.nz',
      'priceHistory': [
        {'date': '2026-06-19', 'price': 4},
      ],
    });

    expect(steak.isCarnivoreCompatible, isTrue);
    expect(steak.isKetoCompatible, isTrue);
    expect(avocado.isKetoCompatible, isTrue);
    expect(avocado.isCarnivoreCompatible, isFalse);
    expect(marketed.isCompatibleWith(GroceryDiet.allCompatible), isFalse);
  });
}

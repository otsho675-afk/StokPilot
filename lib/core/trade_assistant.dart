/// Read-only checks shown before a trade is submitted. The transaction still
/// validates stock and product state against the latest server data.
class BasketLineSnapshot {
  const BasketLineSnapshot({
    required this.id,
    required this.name,
    required this.quantityMilli,
    required this.priceMinor,
  });

  final String id, name;
  final int quantityMilli, priceMinor;
}

enum BasketHintKind { unavailable, insufficient, lowAfterSale, priceChanged }

class BasketHint {
  const BasketHint(this.productId, this.kind, this.message);

  final String productId;
  final BasketHintKind kind;
  final String message;

  bool get blocksSave =>
      kind == BasketHintKind.unavailable || kind == BasketHintKind.insufficient;
}

List<BasketHint> inspectBasket({
  required bool sale,
  required Iterable<BasketLineSnapshot> lines,
  required Map<String, Map<String, dynamic>> products,
}) {
  final hints = <BasketHint>[];
  for (final line in lines) {
    final product = products[line.id];
    if (product == null || product['isActive'] == false) {
      hints.add(
        BasketHint(
          line.id,
          BasketHintKind.unavailable,
          '${line.name}: ürün artık aktif değil. Sepetten çıkarın.',
        ),
      );
      continue;
    }
    if (sale) {
      final stock = (product['stockMilli'] as num?)?.toInt() ?? 0;
      final minimum = (product['minStockMilli'] as num?)?.toInt() ?? 0;
      final remaining = stock - line.quantityMilli;
      if (remaining < 0) {
        hints.add(
          BasketHint(
            line.id,
            BasketHintKind.insufficient,
            '${line.name}: bu miktar için stok yetersiz. Miktarı azaltın.',
          ),
        );
      } else if (remaining <= minimum) {
        hints.add(
          BasketHint(
            line.id,
            BasketHintKind.lowAfterSale,
            '${line.name}: satıştan sonra stok ${remaining <= 0 ? 'tükenecek' : 'kritik seviyeye inecek'}.',
          ),
        );
      }
      final latestPrice = (product['salePriceMinor'] as num?)?.toInt() ?? 0;
      if (latestPrice != line.priceMinor) {
        hints.add(
          BasketHint(
            line.id,
            BasketHintKind.priceChanged,
            '${line.name}: kayıtlı satış fiyatı sepet oluşturulduktan sonra değişti.',
          ),
        );
      }
    }
  }
  return hints;
}

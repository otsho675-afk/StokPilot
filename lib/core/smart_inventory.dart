/// Product matching and reminders shared by the editor and dashboard.
String normalizeProductText(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+', unicode: true), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

enum ProductMatchKind { name, sku, barcode }

class ProductMatch {
  const ProductMatch(this.id, this.name, this.kind);
  final String id;
  final String name;
  final ProductMatchKind kind;
}

ProductMatch? findProductMatch({
  required String name,
  required String sku,
  required String barcode,
  required Iterable<MapEntry<String, Map<String, dynamic>>> products,
  String? excludingId,
}) {
  final normalizedName = normalizeProductText(name);
  final normalizedSku = sku.trim().toLowerCase();
  final normalizedBarcode = barcode.trim();
  for (final item in products) {
    if (item.key == excludingId) continue;
    final record = item.value;
    final productName = (record['name'] ?? '').toString();
    if (normalizedBarcode.isNotEmpty &&
        normalizedBarcode == (record['barcode'] ?? '').toString().trim()) {
      return ProductMatch(item.key, productName, ProductMatchKind.barcode);
    }
    if (normalizedSku.isNotEmpty &&
        normalizedSku ==
            (record['sku'] ?? '').toString().trim().toLowerCase()) {
      return ProductMatch(item.key, productName, ProductMatchKind.sku);
    }
    if (normalizedName.isNotEmpty &&
        normalizedName == normalizeProductText(productName)) {
      return ProductMatch(item.key, productName, ProductMatchKind.name);
    }
  }
  return null;
}

class InventoryAlert {
  const InventoryAlert(
    this.productId,
    this.productName,
    this.kind,
    this.message,
  );
  final String productId;
  final String productName;
  final String kind;
  final String message;
}

List<InventoryAlert> inventoryAlerts(
  Iterable<MapEntry<String, Map<String, dynamic>>> products, {
  required DateTime now,
  required int priceReminderDays,
}) {
  final result = <InventoryAlert>[];
  for (final item in products) {
    final value = item.value;
    if (value['isActive'] == false) continue;
    final name = (value['name'] ?? 'Ürün').toString();
    final stock = (value['stockMilli'] as num?)?.toInt() ?? 0;
    final minimum = (value['minStockMilli'] as num?)?.toInt() ?? 0;
    if (stock <= minimum) {
      result.add(
        InventoryAlert(
          item.key,
          name,
          'stock',
          stock <= 0 ? 'Stok tükendi' : 'Stok kritik seviyede',
        ),
      );
    }
    final date = value['priceChangedAt'] ?? value['createdAt'];
    final changedAt = date is DateTime ? date : null;
    if (changedAt != null &&
        now.difference(changedAt).inDays >= priceReminderDays) {
      result.add(
        InventoryAlert(
          item.key,
          name,
          'price',
          '$priceReminderDays gündür fiyat güncellenmedi',
        ),
      );
    }
  }
  return result;
}

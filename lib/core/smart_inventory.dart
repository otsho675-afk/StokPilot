/// Product matching and reminders shared by the editor and dashboard.
String normalizeProductText(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
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

/// Advisory matches. Call after typing has paused so incomplete names do not
/// create noisy suggestions. Exact duplicates are handled by findProductMatch.
List<ProductMatch> similarProductMatches({
  required String name,
  required Iterable<MapEntry<String, Map<String, dynamic>>> products,
  String? excludingId,
}) {
  final normalized = normalizeProductText(name);
  if (normalized.length < 5) return const [];
  final words = normalized.split(' ').where((word) => word.length > 1).toSet();
  final result = <ProductMatch>[];
  for (final item in products) {
    if (item.key == excludingId) continue;
    final productName = (item.value['name'] ?? '').toString();
    final other = normalizeProductText(productName);
    if (other.isEmpty || other == normalized) continue;
    final otherWords =
        other.split(' ').where((word) => word.length > 1).toSet();
    final shared = words.intersection(otherWords).length;
    final closePhrase =
        (normalized.contains(other) || other.contains(normalized)) &&
        (normalized.length < other.length
                ? normalized.length / other.length
                : other.length / normalized.length) >=
            0.7;
    final closeWords =
        shared >= 2 && shared / words.union(otherWords).length >= 0.6;
    if (closePhrase || closeWords) {
      result.add(ProductMatch(item.key, productName, ProductMatchKind.name));
      if (result.length == 3) break;
    }
  }
  return result;
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

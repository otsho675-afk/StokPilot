import 'dart:math';

/// Unit prices stored in Firestore are VAT-exclusive integer kuruş.
int vatMinor(int netMinor, int taxRateBps) =>
    (netMinor * taxRateBps / 10000).round();

int grossMinor(int netMinor, int taxRateBps) =>
    netMinor + vatMinor(netMinor, taxRateBps);

/// Converts a VAT-inclusive unit price into the VAT-exclusive price stored
/// in Firestore. Searches nearby kuruş values for exact round-trip accuracy.
int netFromGrossMinor(int gross, int taxRateBps) {
  if (gross < 0 || taxRateBps < 0) {
    throw ArgumentError('Fiyat ve KDV negatif olamaz.');
  }
  if (taxRateBps == 0) return gross;
  final candidate = (gross * 10000 / (10000 + taxRateBps)).round();
  for (var delta = -2; delta <= 2; delta++) {
    final value = candidate + delta;
    if (value >= 0 && grossMinor(value, taxRateBps) == gross) return value;
  }
  return candidate;
}

/// Markup: profit / net purchase price (not gross margin).
double? profitMarkupPercent(int purchaseNetMinor, int saleNetMinor) {
  if (purchaseNetMinor <= 0) return null;
  return (saleNetMinor - purchaseNetMinor) * 100 / purchaseNetMinor;
}

/// Internal EAN-13 with prefix 20; not an externally licensed GS1 product code.
String generateInternalBarcode({Random? random}) {
  final r = random ?? Random.secure();
  final body =
      '20${r.nextInt(100000).toString().padLeft(5, '0')}${r.nextInt(100000).toString().padLeft(5, '0')}';
  return body + ean13CheckDigit(body).toString();
}

int ean13CheckDigit(String twelve) {
  if (!RegExp(r'^\d{12}$').hasMatch(twelve)) {
    throw const FormatException('EAN-13 için 12 basamak gerekiyor.');
  }
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = int.parse(twelve[i]);
    sum += digit * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10;
}

bool isValidEan13(String text) =>
    RegExp(r'^\d{13}$').hasMatch(text) &&
    ean13CheckDigit(text.substring(0, 12)) == int.parse(text[12]);

String normalizeProductSearch(String value) =>
    value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();

class ProductSearchEntry {
  const ProductSearchEntry({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.stockMilli,
  });
  final String id, name, sku, barcode;
  final int stockMilli;
}

int productSearchScore(ProductSearchEntry entry, String query) {
  final term = normalizeProductSearch(query);
  if (term.isEmpty) return 1;
  final words = term.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final name = normalizeProductSearch(entry.name);
  final sku = normalizeProductSearch(entry.sku);
  final barcode = normalizeProductSearch(entry.barcode);
  if (!words.every(
    (w) => name.contains(w) || sku.contains(w) || barcode.contains(w),
  )) {
    return -1;
  }
  if (barcode.isNotEmpty && barcode == term) return 1000;
  if (sku.isNotEmpty && sku == term) return 900;
  if (name == term) return 800;
  if (barcode.startsWith(term) && barcode.isNotEmpty) return 700;
  if (sku.startsWith(term) && sku.isNotEmpty) return 650;
  if (name.startsWith(term)) return 600;
  if (name.contains(term)) return 350;
  return 100;
}

List<ProductSearchEntry> findProducts(
  Iterable<ProductSearchEntry> entries,
  String query, {
  int limit = 15,
}) {
  final scored = <(ProductSearchEntry, int)>[];
  for (final entry in entries) {
    final score = productSearchScore(entry, query);
    if (score >= 0) scored.add((entry, score));
  }
  scored.sort((a, b) {
    final rank = b.$2.compareTo(a.$2);
    if (rank != 0) return rank;
    final stock = b.$1.stockMilli.compareTo(a.$1.stockMilli);
    if (stock != 0) return stock;
    return a.$1.name.compareTo(b.$1.name);
  });
  return scored.take(limit).map((item) => item.$1).toList();
}

const salePaymentMethods = ['cash', 'card', 'credit'];

String paymentMethodLabel(String? code) => switch (code) {
  'cash' => 'Nakit',
  'card' => 'Kart',
  'credit' => 'Veresiye',
  'partial' => 'Kısmi ödeme',
  _ => 'Belirtilmemiş',
};

int salePaidMinor(String method, int totalMinor, {required bool hasContact}) {
  if (!salePaymentMethods.contains(method)) {
    throw const FormatException('Geçersiz ödeme yöntemi.');
  }
  if (method == 'credit') {
    if (!hasContact) {
      throw const FormatException('Veresiye satış için müşteri/cari seçin.');
    }
    return 0;
  }
  return totalMinor;
}

/// Read-only ERP reporting calculations. All amounts are integer kurus (minor)
/// and all quantities are thousandths of their stored unit.
/// No client-side computed value is trusted for stock writes or subscriptions.
class ErpLineRank {
  const ErpLineRank({
    required this.name,
    required this.quantityMilli,
    required this.netMinor,
  });
  final String name;
  final int quantityMilli;
  final int netMinor;
}

class ErpMetrics {
  const ErpMetrics({
    required this.productCount,
    required this.lowStockCount,
    required this.emptyStockCount,
    required this.inventoryCostMinor,
    required this.receivableMinor,
    required this.payableMinor,
    required this.saleCount,
    required this.purchaseCount,
    required this.salesGrossMinor,
    required this.salesNetMinor,
    required this.purchasesGrossMinor,
    required this.outputVatMinor,
    required this.inputVatMinor,
    required this.salesPaidMinor,
    required this.purchasesPaidMinor,
    required this.byDay,
    required this.topProducts,
  });

  final int productCount, lowStockCount, emptyStockCount;
  final int inventoryCostMinor, receivableMinor, payableMinor;
  final int saleCount, purchaseCount;
  final int salesGrossMinor, salesNetMinor, purchasesGrossMinor;
  final int outputVatMinor, inputVatMinor;
  final int salesPaidMinor, purchasesPaidMinor;
  final Map<DateTime, int> byDay;
  final List<ErpLineRank> topProducts;

  int get outstandingSalesMinor => salesGrossMinor - salesPaidMinor;
  int get unpaidPurchasesMinor => purchasesGrossMinor - purchasesPaidMinor;
  int get averageSaleMinor =>
      saleCount == 0 ? 0 : (salesGrossMinor / saleCount).round();

  static int _number(dynamic value) => value is num ? value.toInt() : 0;

  static DateTime? _date(dynamic input) {
    if (input is DateTime) return input;
    if (input == null) return null;
    try {
      final date = (input as dynamic).toDate();
      return date is DateTime ? date : null;
    } catch (_) {
      return null;
    }
  }

  static ErpMetrics compute({
    required Iterable<Map<String, dynamic>> products,
    required Iterable<Map<String, dynamic>> trades,
    required Iterable<Map<String, dynamic>> contacts,
    int? lastDays,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    final cutoff =
        lastDays == null ? null : time.subtract(Duration(days: lastDays));
    var productCount = 0;
    var low = 0;
    var empty = 0;
    var inventory = 0;
    var receivable = 0;
    var payable = 0;
    var sales = 0;
    var purchases = 0;
    var gross = 0;
    var net = 0;
    var purchaseGross = 0;
    var outVat = 0;
    var inVat = 0;
    var salesPaid = 0;
    var purchasesPaid = 0;
    final byDay = <DateTime, int>{};
    final quantityByProduct = <String, int>{};
    final netByProduct = <String, int>{};

    for (final product in products) {
      productCount++;
      final stock = _number(product['stockMilli']);
      final min = _number(product['minStockMilli']);
      final unitPrice = _number(product['purchasePriceMinor']);
      inventory += (stock * unitPrice / 1000).round();
      if (product['isActive'] != false) {
        if (stock <= min) low++;
        if (stock <= 0) empty++;
      }
    }
    for (final contact in contacts) {
      final balance = _number(contact['balanceMinor']);
      if (balance >= 0) {
        receivable += balance;
      } else {
        payable += -balance;
      }
    }
    for (final trade in trades) {
      final date = _date(trade['createdAt']);
      if (cutoff != null && (date == null || date.isBefore(cutoff))) continue;
      final total = _number(trade['totalMinor']);
      final paid = _number(trade['paidMinor']);
      final vat = _number(trade['taxMinor']);
      if (trade['type'] == 'sale') {
        sales++;
        gross += total;
        net += _number(trade['netMinor']);
        outVat += vat;
        salesPaid += paid;
        if (date != null) {
          final day = DateTime(date.year, date.month, date.day);
          byDay[day] = (byDay[day] ?? 0) + total;
        }
        final rawLines = trade['lines'];
        if (rawLines is List) {
          for (final raw in rawLines) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final name = (item['name'] ?? 'Bilinmeyen ürün').toString();
            quantityByProduct[name] =
                (quantityByProduct[name] ?? 0) + _number(item['quantityMilli']);
            netByProduct[name] =
                (netByProduct[name] ?? 0) + _number(item['netMinor']);
          }
        }
      } else if (trade['type'] == 'purchase') {
        purchases++;
        purchaseGross += total;
        inVat += vat;
        purchasesPaid += paid;
      }
    }
    final ranking =
        netByProduct.keys
            .map(
              (name) => ErpLineRank(
                name: name,
                quantityMilli: quantityByProduct[name] ?? 0,
                netMinor: netByProduct[name] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.netMinor.compareTo(a.netMinor));
    return ErpMetrics(
      productCount: productCount,
      lowStockCount: low,
      emptyStockCount: empty,
      inventoryCostMinor: inventory,
      receivableMinor: receivable,
      payableMinor: payable,
      saleCount: sales,
      purchaseCount: purchases,
      salesGrossMinor: gross,
      salesNetMinor: net,
      purchasesGrossMinor: purchaseGross,
      outputVatMinor: outVat,
      inputVatMinor: inVat,
      salesPaidMinor: salesPaid,
      purchasesPaidMinor: purchasesPaid,
      byDay: byDay,
      topProducts: ranking,
    );
  }
}

/// CSV for spreadsheet import or clipboard export. Escape formulas to avoid
/// spreadsheet formula injection from user-entered product/contact names.
String erpCsv(Iterable<Iterable<Object?>> rows) {
  String cell(Object? input) {
    var text = (input ?? '').toString();
    if (input is String && RegExp(r'^\s*[=+@-]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return '\uFEFF${rows.map((row) => row.map(cell).join(';')).join('\r\n')}';
}

/// Read-only dashboard calculations. Amounts are stored in integer kuruş.
class DashboardActivity {
  const DashboardActivity({
    required this.type,
    required this.number,
    required this.contact,
    required this.totalMinor,
    required this.method,
    required this.date,
  });

  final String type, number, contact, method;
  final int totalMinor;
  final DateTime date;
}

class DashboardInsights {
  const DashboardInsights({
    required this.salesMinor,
    required this.collectedMinor,
    required this.purchasesMinor,
    required this.saleCount,
    required this.cashMinor,
    required this.cardMinor,
    required this.creditMinor,
    required this.byDay,
    required this.recent,
  });

  final int salesMinor, collectedMinor, purchasesMinor, saleCount;
  final int cashMinor, cardMinor, creditMinor;
  final Map<DateTime, int> byDay;
  final List<DashboardActivity> recent;

  int get averageSaleMinor => saleCount == 0 ? 0 : (salesMinor / saleCount).round();

  static int _minor(dynamic value) => value is num ? value.toInt() : 0;

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    try {
      final converted = (value as dynamic).toDate();
      return converted is DateTime ? converted : null;
    } catch (_) {
      return null;
    }
  }

  static DashboardInsights compute(
    Iterable<Map<String, dynamic>> transactions, {
    required int days,
    DateTime? now,
  }) {
    if (days < 1) throw ArgumentError.value(days, 'days');
    final current = now ?? DateTime.now();
    final since = DateTime(current.year, current.month, current.day)
        .subtract(Duration(days: days - 1));
    var sales = 0, collected = 0, purchases = 0, count = 0;
    var cash = 0, card = 0, credit = 0;
    final daily = <DateTime, int>{};
    final activity = <DashboardActivity>[];
    for (final trade in transactions) {
      final date = _date(trade['createdAt']);
      if (date == null || date.isAfter(current)) continue;
      final type = (trade['type'] ?? '').toString();
      if (type != 'sale' && type != 'purchase') continue;
      final total = _minor(trade['totalMinor']);
      activity.add(DashboardActivity(
        type: type,
        number: (trade['documentNo'] ?? 'İşlem').toString(),
        contact: (trade['contactName'] ?? 'Peşin işlem').toString(),
        totalMinor: total,
        method: (trade['paymentMethod'] ?? '').toString(),
        date: date,
      ));
      if (date.isBefore(since)) continue;
      if (type == 'purchase') {
        purchases += total;
        continue;
      }
      count++;
      sales += total;
      collected += _minor(trade['paidMinor']);
      final day = DateTime(date.year, date.month, date.day);
      daily[day] = (daily[day] ?? 0) + total;
      switch (trade['paymentMethod']) {
        case 'cash':
          cash += total;
        case 'card':
          card += total;
        case 'credit':
          credit += total;
      }
    }
    activity.sort((a, b) => b.date.compareTo(a.date));
    return DashboardInsights(
      salesMinor: sales,
      collectedMinor: collected,
      purchasesMinor: purchases,
      saleCount: count,
      cashMinor: cash,
      cardMinor: card,
      creditMinor: credit,
      byDay: daily,
      recent: activity.take(6).toList(growable: false),
    );
  }
}

class RestockSuggestion {
  const RestockSuggestion({
    required this.id,
    required this.name,
    required this.stockMilli,
    required this.minimumMilli,
    required this.orderMilli,
  });

  final String id, name;
  final int stockMilli, minimumMilli, orderMilli;

  bool get isEmpty => stockMilli <= 0;
}

/// Targets twice the minimum stock, or one unit when the minimum is zero.
/// These are suggestions only; no purchase or inventory writes occur.
List<RestockSuggestion> suggestRestocks(
  Iterable<MapEntry<String, Map<String, dynamic>>> products,
) {
  final result = <RestockSuggestion>[];
  for (final entry in products) {
    final data = entry.value;
    if (data['isActive'] == false) continue;
    final stock = (data['stockMilli'] as num?)?.toInt() ?? 0;
    final minimum = (data['minStockMilli'] as num?)?.toInt() ?? 0;
    if (stock > minimum) continue;
    final target = minimum > 0 ? minimum * 2 : 1000;
    result.add(RestockSuggestion(
      id: entry.key,
      name: (data['name'] ?? 'Ürün').toString(),
      stockMilli: stock,
      minimumMilli: minimum,
      orderMilli: target > stock ? target - stock : 0,
    ));
  }
  result.sort((a, b) {
    final emptyOrder = (b.isEmpty ? 1 : 0).compareTo(a.isEmpty ? 1 : 0);
    if (emptyOrder != 0) return emptyOrder;
    final ratioA = a.minimumMilli > 0 ? a.stockMilli / a.minimumMilli : 0.0;
    final ratioB = b.minimumMilli > 0 ? b.stockMilli / b.minimumMilli : 0.0;
    final byRatio = ratioA.compareTo(ratioB);
    return byRatio != 0 ? byRatio : a.name.compareTo(b.name);
  });
  return result;
}

/// Product selling intelligence without Firestore writes.
/// Amounts are in kurus, quantities in milli-units.
class SalesVelocity {
  const SalesVelocity({
    required this.productId,
    required this.unitsSoldMilli,
    required this.dailyUnitsMilli,
    required this.daysOfCover,
    required this.recommendedOrderMilli,
  });
  final String productId;
  final int unitsSoldMilli;
  final double dailyUnitsMilli;
  final double? daysOfCover;
  final int recommendedOrderMilli;
}

class InventoryForecast {
  /// At least one period day; optional lead time and desired cover.
  static SalesVelocity forProduct({
    required String productId,
    required int stockMilli,
    required int minimumMilli,
    required int soldMilli,
    required int periodDays,
    int leadDays = 7,
    int coverDays = 14,
  }) {
    if (periodDays <= 0 || leadDays < 0 || coverDays < 0) {
      throw ArgumentError('Geçersiz tahmin süresi');
    }
    final daily = soldMilli <= 0 ? 0.0 : soldMilli / periodDays;
    final cover = daily == 0 ? null : stockMilli / daily;
    // Never predict demand without historical sales; use minimum stock
    // as the conservative baseline when there is no sales history.
    final plannedMilli = (daily * (leadDays + coverDays)).ceil();
    final targetMilli = plannedMilli > minimumMilli * 2
        ? plannedMilli : minimumMilli * 2;
    final orderMilli = targetMilli > stockMilli ? targetMilli - stockMilli : 0;
    return SalesVelocity(
      productId: productId,
      unitsSoldMilli: soldMilli,
      dailyUnitsMilli: daily,
      daysOfCover: cover,
      recommendedOrderMilli: orderMilli,
    );
  }

  /// Sum actual sold quantities from historical sale lines. Never include
  /// purchases, drafts or records outside the requested period.
  static Map<String, int> soldByProduct(
    Iterable<Map<String, dynamic>> trades, {
    required DateTime now,
    required int periodDays,
  }) {
    if (periodDays <= 0) throw ArgumentError.value(periodDays, 'periodDays');
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: periodDays - 1));
    final sold = <String, int>{};
    for (final trade in trades) {
      if (trade['type'] != 'sale') continue;
      final stamp = trade['createdAt'];
      DateTime? date;
      if (stamp is DateTime) {
        date = stamp;
      } else {
        try {
          date = (stamp as dynamic).toDate() as DateTime?;
        } catch (_) {
          continue;
        }
      }
      if (date == null || date.isBefore(since) || date.isAfter(now)) continue;
      final raw = trade['lines'];
      if (raw is! List) continue;
      for (final line in raw) {
        if (line is! Map) continue;
        final id = (line['productId'] ?? '').toString();
        final quantity = line['quantityMilli'];
        if (id.isEmpty || quantity is! num || quantity <= 0) continue;
        sold[id] = (sold[id] ?? 0) + quantity.toInt();
      }
    }
    return sold;
  }
}

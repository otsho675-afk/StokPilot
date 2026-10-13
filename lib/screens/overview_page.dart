import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/dashboard_insights.dart';
import '../core/inventory_forecast.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

/// Responsive, read-only ERP dashboard using existing Firestore collections.
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    const actions = <(String, IconData, int)>[
      ('Yeni Satış', Icons.receipt_long_outlined, 2),
      ('Yeni Ürün', Icons.inventory_2_outlined, 1),
      ('Yeni Cari', Icons.person_add_alt_1_outlined, 4),
      ('Yeni Alış', Icons.shopping_bag_outlined, 3),
      ('Tahsilat', Icons.payments_outlined, 6),
      ('Raporlar', Icons.bar_chart_rounded, 7),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hızlı işlemler',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 5),
        const Text('En sık kullandığınız işlemlere tek dokunuşla ulaşın.',
          style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 440 ? 2 : constraints.maxWidth < 850 ? 3 : 6;
          final spacing = 12.0;
          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in actions)
                SizedBox(
                  width: width,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onNavigate(action.$3),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 122),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                        decoration: BoxDecoration(
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(action.$2, size: 29, color: const Color(0xFF1255B7)),
                            const SizedBox(height: 12),
                            Text(action.$1, textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _OverviewPageState extends State<OverviewPage> {
  int periodDays = 7;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _QuickActions(onNavigate: widget.onNavigate),
      const SizedBox(height: 18),
      _Hero(onNavigate: widget.onNavigate),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, size) {
          final headline = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İşletme kontrol merkezi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Satışlar, tahsilat, kritik stoklar ve cari bakiyeler',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ],
          );
          final period = Wrap(
            spacing: 7,
            children: [
              for (final item in [(7, '7 gün'), (30, '30 gün'), (90, '90 gün')])
                ChoiceChip(
                  label: Text(item.$2),
                  showCheckmark: false,
                  selected: periodDays == item.$1,
                  onSelected: (_) => setState(() => periodDays = item.$1),
                ),
            ],
          );
          if (size.maxWidth < 610) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headline, const SizedBox(height: 10), period],
            );
          }
          return Row(children: [Expanded(child: headline), period]);
        },
      ),
      const SizedBox(height: 14),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('products'),
        builder: (context, ps) {
          if (ps.hasError) return _error('Ürünler', ps.error);
          if (!ps.hasData) return const LinearProgressIndicator();
          final products = ps.data!.docs;
          final restocks = suggestRestocks(
            products.map((item) => MapEntry(item.id, item.data())),
          );
          final stockCost = products.fold<int>(0, (totalAmount, item) {
            final product = item.data();
            final stock = (product['stockMilli'] as num?)?.toInt() ?? 0;
            final price = (product['purchasePriceMinor'] as num?)?.toInt() ?? 0;
            return totalAmount + (stock * price / 1000).round();
          });
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppApi.instance.watch('contacts'),
            builder: (context, cs) {
              if (cs.hasError) return _error('Cariler', cs.error);
              if (!cs.hasData) return const LinearProgressIndicator();
              var receivable = 0, payable = 0;
              for (final contact in cs.data!.docs) {
                final balance =
                    (contact.data()['balanceMinor'] as num?)?.toInt() ?? 0;
                if (balance > 0) receivable += balance;
                if (balance < 0) payable -= balance;
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppApi.instance.watch('trades'),
                builder: (context, ts) {
                  if (ts.hasError) return _error('İşlemler', ts.error);
                  if (!ts.hasData) return const LinearProgressIndicator();
                  final stats = DashboardInsights.compute(
                    ts.data!.docs.map((item) => item.data()),
                    days: periodDays,
                  );
                  final sold = InventoryForecast.soldByProduct(
                    ts.data!.docs.map((doc) => doc.data()),
                    now: DateTime.now(),
                    periodDays: 30,
                  );
                  final forecast = <String, SalesVelocity>{
                    for (final product in products)
                      product.id: InventoryForecast.forProduct(
                        productId: product.id,
                        stockMilli: (product.data()['stockMilli'] as num?)?.toInt() ?? 0,
                        minimumMilli: (product.data()['minStockMilli'] as num?)?.toInt() ?? 0,
                        soldMilli: sold[product.id] ?? 0,
                        periodDays: 30,
                      ),
                  };
                  final cards = <_Kpi>[
                    _Kpi(
                      'Satış cirosu',
                      money(stats.salesMinor),
                      Icons.trending_up_rounded,
                      'Son $periodDays gün',
                      7,
                    ),
                    _Kpi(
                      'Tahsil edilen',
                      money(stats.collectedMinor),
                      Icons.payments_rounded,
                      'İşlem anındaki tahsilat',
                      6,
                    ),
                    _Kpi(
                      'Satış işlemi',
                      '${stats.saleCount}',
                      Icons.receipt_long_outlined,
                      'Kaydedilmiş fiş sayısı',
                      2,
                    ),
                    _Kpi(
                      'Ortalama sepet',
                      money(stats.averageSaleMinor),
                      Icons.bar_chart_rounded,
                      'KDV dâhil satış ortalaması',
                      7,
                    ),
                    _Kpi(
                      'Stok maliyeti',
                      money(stockCost),
                      Icons.warehouse_outlined,
                      'Güncel alış fiyatı',
                      1,
                    ),
                    _Kpi(
                      'Kritik stok',
                      '${restocks.length}',
                      Icons.warning_amber_rounded,
                      '${restocks.where((p) => p.isEmpty).length} üründe stok tükenmiş',
                      1,
                    ),
                    _Kpi(
                      'Cari alacak',
                      money(receivable),
                      Icons.account_balance_wallet_outlined,
                      'Güncel müşteri bakiyesi',
                      4,
                    ),
                    _Kpi(
                      'Cari borç',
                      money(payable),
                      Icons.account_balance_outlined,
                      'Güncel tedarikçi bakiyesi',
                      5,
                    ),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final cols =
                              c.maxWidth >= 1000
                                  ? 4
                                  : c.maxWidth >= 500
                                  ? 2
                                  : 1;
                          final width = (c.maxWidth - (cols - 1) * 12) / cols;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final item in cards)
                                SizedBox(
                                  width: width,
                                  child: MetricCard(
                                    title: item.title,
                                    value: item.value,
                                    icon: item.icon,
                                    subtext: item.detail,
                                    onTap: () => widget.onNavigate(item.page),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      LayoutBuilder(
                        builder: (context, c) {
                          final chart = _TrendPanel(
                            stats: stats,
                            onNavigate: widget.onNavigate,
                          );
                          final breakdown = _PaymentPanel(stats: stats);
                          if (c.maxWidth < 860) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 14),
                                breakdown,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: chart),
                              const SizedBox(width: 14),
                              Expanded(flex: 4, child: breakdown),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      LayoutBuilder(
                        builder: (context, c) {
                          final restockPanel = _RestockPanel(
                            restocks: restocks,
                            forecast: forecast,
                            onNavigate: widget.onNavigate,
                          );
                          final recent = _RecentPanel(
                            stats: stats,
                            onNavigate: widget.onNavigate,
                          );
                          if (c.maxWidth < 860) {
                            return Column(
                              children: [
                                restockPanel,
                                const SizedBox(height: 14),
                                recent,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: restockPanel),
                              const SizedBox(width: 14),
                              Expanded(child: recent),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      _QuickActions(onNavigate: widget.onNavigate),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ],
  );

  Widget _error(String source, Object? error) => DataPanel(
    child: Text(
      '$source okunamadı: $error',
      style: const TextStyle(color: Color(0xFFC2574B)),
    ),
  );
}

class _Kpi {
  const _Kpi(this.title, this.value, this.icon, this.detail, this.page);
  final String title, value, detail;
  final IconData icon;
  final int page;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onNavigate});
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF102A35), Color(0xFF14534D), Color(0xFF087C68)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Stack(
      children: [
        Positioned(
          top: -75,
          right: -72,
          child: Container(
            height: 240,
            width: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 40,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    color: Color(0xFF73EAC8),
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'STOKPILOT  /  İŞLETME PANELİ',
                    style: TextStyle(
                      color: Color(0xFFB7DED4),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'İşletmen, tek bakışta.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Satışları izle, kritik stokları önceden gör ve işlerini hızlandır.',
                style: TextStyle(color: Color(0xFFCAE6DF), height: 1.45),
              ),
              const SizedBox(height: 19),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.icon(
                    onPressed: () => onNavigate(2),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ink,
                    ),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: const Text('Yeni satış'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF86C5B9)),
                    ),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Ürünler'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.stats, required this.onNavigate});
  final DashboardInsights stats;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dates = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DateTime(day.year, day.month, day.day);
    });
    final values = dates.map((d) => stats.byDay[d] ?? 0).toList();
    final maxValue = values.fold<int>(0, (a, b) => b > a ? b : a);
    return DataPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Günlük satış eğilimi',
            subtitle: 'Son 7 gün · KDV dâhil satış',
            trailing: IconButton(
              tooltip: 'Detaylı raporlar',
              onPressed: () => onNavigate(7),
              icon: const Icon(Icons.arrow_outward_rounded),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 158,
            child: Row(
              children: [
                for (var i = 0; i < dates.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 0.7,
                                heightFactor:
                                    maxValue == 0
                                        ? 0.04
                                        : (values[i] / maxValue).clamp(
                                          0.04,
                                          1.0,
                                        ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors:
                                          values[i] == 0
                                              ? [line, line]
                                              : [
                                                const Color(0xFF2BC3A6),
                                                green,
                                              ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            DateFormat('EEE', 'tr_TR').format(dates[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 22),
          Text(
            'Son 7 gün toplamı: ${money(values.fold<int>(0, (a, b) => a + b))}',
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({required this.stats});
  final DashboardInsights stats;
  @override
  Widget build(BuildContext context) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Satış dağılımı',
          subtitle: 'Seçilen dönemin ödeme yöntemleri',
        ),
        const SizedBox(height: 18),
        _bar('Nakit', stats.cashMinor, const Color(0xFF087C68)),
        const SizedBox(height: 14),
        _bar('Kart', stats.cardMinor, const Color(0xFF4078C0)),
        const SizedBox(height: 14),
        _bar('Veresiye', stats.creditMinor, amber),
        const Divider(height: 30),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dönem alışları',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
            Flexible(
              child: Text(
                money(stats.purchasesMinor),
                textAlign: TextAlign.end,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Ödeme türleri işlem kayıtlarına göre hesaplanır. Cari bakiye değildir.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.4),
        ),
      ],
    ),
  );
  Widget _bar(String name, int value, Color accent) {
    final total = stats.salesMinor;
    final percent = total <= 0 ? 0 : (value / total * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$percent% · ${money(value)}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : (value / total).clamp(0.0, 1.0),
            minHeight: 8,
            color: accent,
            backgroundColor: canvas,
          ),
        ),
      ],
    );
  }
}

class _RestockPanel extends StatelessWidget {
  const _RestockPanel({required this.restocks, required this.forecast, required this.onNavigate});
  final List<RestockSuggestion> restocks;
  final Map<String, SalesVelocity> forecast;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: 'Akıllı stok planı',
          subtitle: 'Satış geçmişinden stok ihtiyacı tahmini',
          trailing: IconButton(
            onPressed: () => onNavigate(1),
            tooltip: 'Ürünlere git',
            icon: const Icon(Icons.arrow_outward_rounded),
          ),
        ),
        const SizedBox(height: 8),
        if (restocks.isEmpty)
          const BlankState(
            title: 'Stoklar kontrol altında',
            message: 'Kritik seviyede aktif ürün bulunmuyor.',
            icon: Icons.verified_outlined,
          )
        else ...[
          for (final item in restocks.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color:
                          item.isEmpty
                              ? const Color(0xFFFFEEEE)
                              : const Color(0xFFFFF3E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.isEmpty
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: item.isEmpty ? const Color(0xFFC2574B) : amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Mevcut: ${quantity(item.stockMilli)} · '
                          '${forecast[item.id]?.daysOfCover == null ? 'Satış geçmişi yok' : 'Yaklaşık ${forecast[item.id]!.daysOfCover!.toStringAsFixed(0)} gün yeter'}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${quantity(forecast[item.id]?.recommendedOrderMilli ?? item.orderMilli)}',
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'önerilen',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyList(context),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Sipariş listesini kopyala'),
              ),
              TextButton(
                onPressed: () => onNavigate(1),
                child: Text('Tüm ${restocks.length} ürün'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Tahmin: son 30 gün satış hızı; 7 gün tedarik + 14 gün hedef stok. Geçmiş yoksa asgari stok kullanılır. Otomatik sipariş verilmez.',
          style: TextStyle(color: muted, fontSize: 11, height: 1.4),
        ),
      ],
    ),
  );
  Future<void> _copyList(BuildContext context) async {
    String safe(String value) {
      final singleLine = value.replaceAll('\n', ' ').replaceAll('\r', ' ');
      final guarded =
          RegExp(r'^\s*[=+\-@]').hasMatch(singleLine)
              ? "'$singleLine"
              : singleLine;
      return '"${guarded.replaceAll('"', '""')}"';
    }

    final rows = ['Ürün;Stok;Minimum;Önerilen'];
    for (final p in restocks) {
      rows.add(
        '${safe(p.name)};${quantity(p.stockMilli)};'
        '${quantity(p.minimumMilli)};${quantity(forecast[p.id]?.recommendedOrderMilli ?? p.orderMilli)}',
      );
    }
    await Clipboard.setData(ClipboardData(text: '\uFEFF${rows.join('\r\n')}'));
    if (context.mounted) {
      notify(context, '${restocks.length} ürünlük sipariş önerisi kopyalandı.');
    }
  }
}

class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.stats, required this.onNavigate});
  final DashboardInsights stats;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: 'Son işlemler',
          subtitle: 'En yeni satış ve alış fişleri',
          trailing: IconButton(
            onPressed: () => onNavigate(8),
            tooltip: 'İşlem defterine git',
            icon: const Icon(Icons.arrow_outward_rounded),
          ),
        ),
        const SizedBox(height: 8),
        if (stats.recent.isEmpty)
          const BlankState(
            title: 'Henüz fiş yok',
            message: 'İlk satış veya alış burada görünecek.',
            icon: Icons.receipt_long_outlined,
          )
        else
          for (final item in stats.recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color:
                          item.type == 'sale'
                              ? softGreen
                              : const Color(0xFFFFF3E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.type == 'sale'
                          ? Icons.north_east_rounded
                          : Icons.south_west_rounded,
                      color: item.type == 'sale' ? green : amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.type == 'sale' ? 'Satış' : 'Alış'} · ${item.number}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item.contact} · ${DateFormat('dd.MM HH:mm', 'tr_TR').format(item.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      money(item.totalMinor),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (stats.recent.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onNavigate(8),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('İşlem defteri'),
            ),
          ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          title: 'Hızlı işlemler',
          subtitle: 'Sık kullanılan işlemlere tek dokunuş',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols =
                c.maxWidth >= 800
                    ? 4
                    : c.maxWidth >= 440
                    ? 2
                    : 1;
            final width = (c.maxWidth - (cols - 1) * 10) / cols;
            final buttons = [
              (2, 'Satış oluştur', Icons.point_of_sale_rounded),
              (3, 'Alış kaydet', Icons.add_shopping_cart_outlined),
              (4, 'Müşteri carileri', Icons.people_outline_rounded),
              (6, 'Finans merkezi', Icons.account_balance_wallet_outlined),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in buttons)
                  SizedBox(
                    width: width,
                    child: Material(
                      color: canvas,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        onTap: () => onNavigate(item.$1),
                        borderRadius: BorderRadius.circular(13),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              Icon(item.$3, size: 20, color: green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.$2,
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 17,
                                color: muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

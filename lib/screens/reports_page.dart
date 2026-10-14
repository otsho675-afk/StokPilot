import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../erp/erp_metrics.dart';
import '../erp/finance_ledger.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String period = '30';
  int topPage = 0, topSize = 5, warningPage = 0, warningSize = 5;
  DateTime? startDate;
  DateTime? endDate;

  Future<void> _chooseDate(bool start) async {
    final now = DateTime.now();
    final picked = await showPilotDatePicker(
      context: context,
      initialDate: (start ? startDate : endDate) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      period = 'custom';
      if (start) { startDate = picked; } else { endDate = picked; }
    });
  }


  bool _withinRange(Map<String, dynamic> data) {
    final value = data['createdAt'];
    final date = value is Timestamp ? value.toDate() : null;
    if (date == null) return period == 'all';
    if (period == 'all') return true;
    if (period == 'custom') {
      if (startDate != null && date.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) { return false; }
      if (endDate != null && !date.isBefore(DateTime(endDate!.year, endDate!.month, endDate!.day + 1))) { return false; }
      return true;
    }
    return !date.isBefore(DateTime.now().subtract(Duration(days: int.parse(period))));
  }


  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageTitle(
        title: 'Analiz ve raporlar',
        subtitle: 'Satış, alış, nakit tahsilatı, stok ve cari görünürlüğü.',
      ),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          _period('7', '7 gün'),
          _period('30', '30 gün'),
          _period('90', '90 gün'),
          _period('all', 'Tüm zamanlar'),
        ],
      ),
      const SizedBox(height: 12),
      ResponsiveFields(
        first: CompactDateField(
          label: 'Başlangıç tarihi',
          date: startDate,
          onTap: () => _chooseDate(true),
          onClear: () => setState(() { startDate = null; period = 'custom'; }),
        ),
        second: CompactDateField(
          label: 'Bitiş tarihi',
          date: endDate,
          onTap: () => _chooseDate(false),
          onClear: () => setState(() { endDate = null; period = 'custom'; }),
        ),
      ),
      if (period == 'custom') Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => setState(() { period = '30'; startDate = null; endDate = null; }),
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: const Text('Tarihleri sıfırla'),
        ),
      ),
      const SizedBox(height: 16),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('trades'),
        builder: (context, trades) {
          if (trades.hasError) return _failure(trades.error);
          if (!trades.hasData) return const LinearProgressIndicator();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppApi.instance.watch('products'),
            builder: (context, products) {
              if (products.hasError) return _failure(products.error);
              if (!products.hasData) return const LinearProgressIndicator();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppApi.instance.watch('contacts'),
                builder: (context, contacts) {
                  if (contacts.hasError) return _failure(contacts.error);
                  if (!contacts.hasData) return const LinearProgressIndicator();
                  final metrics = ErpMetrics.compute(
                    products: products.data!.docs.map((d) => d.data()),
                    trades: trades.data!.docs.map((d) => d.data()).where(_withinRange),
                    contacts: contacts.data!.docs.map((d) => d.data()),
                    lastDays: period == 'all' || period == 'custom' ? null : int.parse(period),
                  );
                  final warningProducts =
                      products.data!.docs.where((doc) {
                          final product = doc.data();
                          final stock =
                              (product['stockMilli'] as num?)?.toInt() ?? 0;
                          final min =
                              (product['minStockMilli'] as num?)?.toInt() ?? 0;
                          return product['isActive'] != false && stock <= min;
                        }).toList()
                        ..sort(
                          (a, b) =>
                              ((a.data()['stockMilli'] as num?)?.toInt() ?? 0)
                                  .compareTo(
                                    (b.data()['stockMilli'] as num?)?.toInt() ??
                                        0,
                                  ),
                        );
                  final totals = <String, int>{
                    'cash': 0,
                    'card': 0,
                    'credit': 0,
                    'other': 0,
                  };
                  for (final doc in trades.data!.docs) {
                    final trade = doc.data();
                    if (trade['type'] != 'sale') continue;
                    if (!_withinRange(trade)) {
                      continue;
                    }
                    final method = trade['paymentMethod']?.toString() ?? '';
                    final key = totals.containsKey(method) ? method : 'other';
                    totals[key] =
                        totals[key]! +
                        ((trade['totalMinor'] as num?)?.toInt() ?? 0);
                  }
                  return _body(context, metrics, warningProducts, totals);
                },
              );
            },
          );
        },
      ),
    ],
  );

  Widget _failure(Object? error) => DataPanel(
    child: Text(
      error.toString().contains('permission-denied')
          ? 'Raporlara erişim reddedildi. Oturumu yenileyip tekrar deneyin.'
          : 'Rapor verisi alınamadı: $error',
      style: const TextStyle(color: Color(0xFFB73232)),
    ),
  );

  Widget _period(String code, String text) => ChoiceChip(
    label: Text(text),
    selected: period == code,
    onSelected: (_) => setState(() { period = code; startDate = null; endDate = null; }),
  );

  Future<void> _copyReport(BuildContext context, ErpMetrics metrics) async {
    final days = metrics.byDay.keys.toList()..sort();
    final csv = erpCsv([
      [
        'StokPilot Yönetim Raporu',
        period == 'all' ? 'Tüm zamanlar' : period == 'custom' ? 'Özel tarih aralığı' : 'Son $period gün',
      ],
      ['Gösterge', 'Değer (kuruş veya adet)'],
      ['Satış işlemi', metrics.saleCount],
      ['Satış toplamı', metrics.salesGrossMinor],
      ['Satış KDV', metrics.outputVatMinor],
      ['Satış tahsil edilen', metrics.salesPaidMinor],
      ['Satış açık bakiye', metrics.outstandingSalesMinor],
      ['Alış işlemi', metrics.purchaseCount],
      ['Alış toplamı', metrics.purchasesGrossMinor],
      ['Alış KDV', metrics.inputVatMinor],
      ['Alış ödenen', metrics.purchasesPaidMinor],
      ['Güncel stok maliyet değeri', metrics.inventoryCostMinor],
      ['Cari alacak', metrics.receivableMinor],
      ['Cari borç', metrics.payableMinor],
      [],
      ['Tarih', 'Günlük satış (kuruş)'],
      ...days.map(
        (d) => [
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
          metrics.byDay[d] ?? 0,
        ],
      ),
      [],
      ['Ürün', 'Satılan miktar (x1000)', 'Net satış (kuruş)'],
      ...metrics.topProducts.map((p) => [p.name, p.quantityMilli, p.netMinor]),
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) notify(context, 'Rapor CSV olarak panoya kopyalandı.');
  }

  Widget _body(
    BuildContext context,
    ErpMetrics m,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> warnings,
    Map<String, int> paymentTotals,
  ) {
    final periodName = period == 'all' ? 'Tüm dönem' : period == 'custom' ? 'Seçilen tarih aralığı' : 'Son $period gün';
    final sortedDates = m.byDay.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5F2),
            border: Border.all(color: const Color(0xFFCEE7E0)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: LayoutBuilder(
            builder: (context, size) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finansal genel görünüm',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$periodName • İşletme kayıtlarından hesaplanır',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              );
              final export = OutlinedButton.icon(
                onPressed: () => _copyReport(context, m),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('CSV kopyala'),
              );
              if (size.maxWidth < 470) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), export],
                );
              }
              return Row(children: [Expanded(child: title), export]);
            },
          ),
        ),
        const SizedBox(height: 18),
        _metricGrid([
          MetricCard(
            title: 'Satış cirosu (KDV dahil)',
            value: money(m.salesGrossMinor),
            icon: Icons.trending_up_rounded,
            subtext: '${m.saleCount} satış işlemi',
          ),
          MetricCard(
            title: 'Alış toplamı (KDV dahil)',
            value: money(m.purchasesGrossMinor),
            icon: Icons.shopping_cart_outlined,
            subtext: '${m.purchaseCount} alış işlemi',
          ),
          MetricCard(
            title: 'Satış tahsilatı',
            value: money(m.salesPaidMinor),
            icon: Icons.payments_outlined,
            subtext: 'Dönem satışlarında kaydedilen ödeme',
          ),
          MetricCard(
            title: 'Satış açık tutarı',
            value: money(m.outstandingSalesMinor),
            icon: Icons.pending_actions_outlined,
            subtext: 'Dönem satışlarından ilk kalan tutar',
          ),
          MetricCard(
            title: 'Güncel stok maliyeti',
            value: money(m.inventoryCostMinor),
            icon: Icons.warehouse_outlined,
            subtext: 'Güncel miktar × son tanımlı alış fiyatı',
          ),
          MetricCard(
            title: 'Cari alacak / borç',
            value: '${money(m.receivableMinor)} / ${money(m.payableMinor)}',
            icon: Icons.account_balance_wallet_outlined,
            subtext: 'Güncel cari bakiyeler • tüm zamanlar',
          ),
        ]),
        const SizedBox(height: 14),
        _financeSummary(),
        const SizedBox(height: 14),
        _metricGrid([
          MetricCard(title: 'Nakit satışlar', value: money(paymentTotals['cash'] ?? 0), icon: Icons.payments_rounded, accent: const Color(0xFF0C9672)),
          MetricCard(title: 'POS / Kart satışları', value: money(paymentTotals['card'] ?? 0), icon: Icons.credit_card_rounded, accent: const Color(0xFF2563EB)),
          MetricCard(title: 'Veresiye satışlar', value: money(paymentTotals['credit'] ?? 0), icon: Icons.receipt_long_rounded, accent: const Color(0xFFB7791F)),
        ]),
        const SizedBox(height: 14),
        DataPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading(
                title: 'Ödeme yöntemleri',
                subtitle: 'Seçilen dönemde ödeme tiplerine göre satış hacmi',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _paymentSummary(
                    'Nakit',
                    paymentTotals['cash'] ?? 0,
                    Icons.payments_outlined,
                  ),
                  _paymentSummary(
                    'Kart',
                    paymentTotals['card'] ?? 0,
                    Icons.credit_card_outlined,
                  ),
                  _paymentSummary(
                    'Veresiye',
                    paymentTotals['credit'] ?? 0,
                    Icons.receipt_long_outlined,
                  ),
                  if ((paymentTotals['other'] ?? 0) > 0)
                    _paymentSummary(
                      'Eski kayıtlar',
                      paymentTotals['other'] ?? 0,
                      Icons.history,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Buradaki tutarlar satış toplamıdır. Veresiye, tahsilat anlamına gelmez.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DataPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading(
                title: 'Satış eğilimi',
                subtitle: 'Günlük KDV dahil satış hacmi',
              ),
              const SizedBox(height: 14),
              if (sortedDates.length < 2)
                const BlankState(
                  title: 'Grafik için veri bekleniyor',
                  message:
                      'En az iki ayrı günde satış kaydı oluşturulduğunda grafik görünür.',
                  icon: Icons.show_chart_rounded,
                )
              else
                SizedBox(
                  height: 215,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            sortedDates.length,
                            (i) => FlSpot(
                              i.toDouble(),
                              (m.byDay[sortedDates[i]] ?? 0) / 100,
                            ),
                          ),
                          color: green,
                          barWidth: 3,
                          isCurved: false,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: softGreen.withValues(alpha: .65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, bounds) {
            final summaries = [_vatPanel(m), _topProducts(m)];
            if (bounds.maxWidth < 820) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summaries[0],
                  const SizedBox(height: 14),
                  summaries[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summaries[0]),
                const SizedBox(width: 14),
                Expanded(child: summaries[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        DataPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                title: 'Kritik stok aksiyon listesi',
                subtitle:
                    '${m.lowStockCount} kritik • ${m.emptyStockCount} tükenen aktif ürün',
              ),
              const SizedBox(height: 10),
              if (warnings.isEmpty)
                const BlankState(
                  title: 'Kritik stok yok',
                  message:
                      'Aktif ürünlerin stok seviyeleri tanımlı eşiklerin üzerinde.',
                  icon: Icons.task_alt_rounded,
                ),
              ...warnings.skip(warningPage.clamp(0, ((warnings.length + warningSize - 1) ~/ warningSize).clamp(1, 999999) - 1) * warningSize).take(warningSize).map((doc) {
                final product = doc.data();
                final name = (product['name'] ?? 'Ürün').toString();
                final stock = (product['stockMilli'] as num?)?.toInt() ?? 0;
                final min = (product['minStockMilli'] as num?)?.toInt() ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: amber,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Kritik eşik: ${quantity(min)}'),
                  trailing: Text(
                    quantity(stock),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              }),
              ListPager(
                total: warnings.length,
                page: warningPage,
                pageSize: warningSize,
                onPageChanged: (n) => setState(() => warningPage = n),
                onPageSizeChanged: (n) => setState(() { warningSize = n; warningPage = 0; }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Bilgilendirme: Bu ekran resmî fatura, muhasebe defteri veya '
            'KDV beyannamesi değildir. Dönem tahsilatı yalnızca işlemin kaydı '
            'sırasında girilen ödemeyi içerir; sonradan yapılan cari tahsilatlar '
            'ayrı kayıtlardır. Satış ile alış farkı kâr anlamına gelmez.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _paymentSummary(String method, int amount, IconData symbol) =>
      Container(
        constraints: const BoxConstraints(minWidth: 145),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(symbol, size: 17, color: green),
                const SizedBox(width: 7),
                Text(
                  method,
                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              money(amount),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ],
        ),
      );

  Widget
  _financeSummary() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.watch('payments'),
    builder: (context, payments) {
      if (payments.hasError) return _failure(payments.error);
      if (!payments.hasData) return const LinearProgressIndicator();
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('expenses'),
        builder: (context, expenses) {
          if (expenses.hasError) return _failure(expenses.error);
          if (!expenses.hasData) return const LinearProgressIndicator();
          final since = period == 'all' || period == 'custom'
              ? null : DateTime.now().subtract(Duration(days: int.parse(period)));
          final selectedPayments = payments.data!.docs.map((d) => d.data())
              .where((data) => period != 'custom' || _withinRange(data));
          final selectedExpenses = expenses.data!.docs.map((d) => d.data())
              .where((data) => period != 'custom' || _withinRange(data));
          final totals = FinanceTotals.compute(
            payments: selectedPayments,
            expenses: selectedExpenses,
            since: since,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metricGrid([
                MetricCard(
                  title: 'Müşteri tahsilatları',
                  value: money(totals.collectionsMinor),
                  icon: Icons.call_received_rounded,
                  accent: const Color(0xFF0D9874),
                ),
                MetricCard(
                  title: 'Firma / tedarikçi ödemeleri',
                  value: money(totals.payoutsMinor),
                  icon: Icons.local_shipping_outlined,
                  accent: const Color(0xFF2563EB),
                ),
                MetricCard(
                  title: 'İşletme giderleri',
                  value: money(totals.expensesMinor),
                  icon: Icons.receipt_long_outlined,
                  accent: const Color(0xFFC17C27),
                ),
              ]),
              const SizedBox(height: 14),
              DataPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading(
                      title: 'Para hareketi özeti',
                  subtitle:
                      'Seçilen dönemde kaydedilen tahsilat, ödeme ve giderler',
                ),
                const SizedBox(height: 10),
                _summaryRow('Tahsilatlar', money(totals.collectionsMinor)),
                _summaryRow('Tedarikçi ödemeleri', money(totals.payoutsMinor)),
                _summaryRow('İşletme giderleri', money(totals.expensesMinor)),
                const Divider(),
                _summaryRow(
                  'Net para hareketi',
                  money(totals.netMinor),
                  highlighted: true,
                ),
                const SizedBox(height: 7),
                const Text(
                  'Bu tutar kayıtlı para hareketlerinin farkıdır; kâr veya banka bakiyesi değildir.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _metricGrid(List<Widget> cards) => LayoutBuilder(
    builder: (context, c) {
      final cols =
          c.maxWidth >= 1100
              ? 3
              : c.maxWidth >= 610
              ? 2
              : 1;
      final width = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );

  Widget _vatPanel(ErpMetrics metrics) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          title: 'KDV görünümü',
          subtitle: 'Kayıtlardan hesaplanan, beyan yerine geçmeyen tutarlar',
        ),
        const SizedBox(height: 12),
        _summaryRow('Satış KDV', money(metrics.outputVatMinor)),
        _summaryRow('Alış KDV', money(metrics.inputVatMinor)),
        const Divider(),
        _summaryRow(
          'Fark',
          money(metrics.outputVatMinor - metrics.inputVatMinor),
          highlighted: true,
        ),
        const SizedBox(height: 10),
        _summaryRow('Ortalama satış', money(metrics.averageSaleMinor)),
      ],
    ),
  );

  Widget _topProducts(ErpMetrics metrics) => DataPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          title: 'En çok ciro getiren ürünler',
          subtitle: 'KDV hariç satılan kalemlerden hesaplanır',
        ),
        const SizedBox(height: 10),
        if (metrics.topProducts.isEmpty)
          const BlankState(
            title: 'Satış kalemi yok',
            message: 'Satış yaptıkça ürün sıralaması burada görünür.',
            icon: Icons.bar_chart_rounded,
          ),
        ...metrics.topProducts.asMap().entries
          .skip(topPage.clamp(0, ((metrics.topProducts.length + topSize - 1) ~/ topSize).clamp(1, 999999) - 1) * topSize)
          .take(topSize).map((entry) {
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${entry.key + 1}.',
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Miktar: ${quantity(item.quantityMilli)}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  money(item.netMinor),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          );
        }),
        ListPager(
          total: metrics.topProducts.length,
          page: topPage,
          pageSize: topSize,
          onPageChanged: (n) => setState(() => topPage = n),
          onPageSizeChanged: (n) => setState(() { topSize = n; topPage = 0; }),
        ),
      ],
    ),
  );

  Widget _summaryRow(String title, String value, {bool highlighted = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(color: muted))),
            Text(
              value,
              style: TextStyle(
                color: highlighted ? green : ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

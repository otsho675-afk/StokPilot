import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/sales_tools.dart';
import '../erp/erp_metrics.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String period = '30';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageTitle(title: 'Yönetim raporları',
        subtitle: 'Satış, alış, nakit tahsilatı, stok ve cari görünürlüğü.'),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _period('7', '7 gün'),
        _period('30', '30 gün'),
        _period('90', '90 gün'),
        _period('all', 'Tüm zamanlar'),
      ]),
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
                    trades: trades.data!.docs.map((d) => d.data()),
                    contacts: contacts.data!.docs.map((d) => d.data()),
                    lastDays: period == 'all' ? null : int.parse(period),
                  );
                  final warningProducts = products.data!.docs.where((doc) {
                    final product = doc.data();
                    final stock = (product['stockMilli'] as num?)?.toInt() ?? 0;
                    final min = (product['minStockMilli'] as num?)?.toInt() ?? 0;
                    return product['isActive'] != false && stock <= min;
                  }).toList()..sort((a,b) =>
                    ((a.data()['stockMilli'] as num?)?.toInt() ?? 0).compareTo(
                      (b.data()['stockMilli'] as num?)?.toInt() ?? 0));
                  final now = DateTime.now();
                  final since = period == 'all' ? null :
                    now.subtract(Duration(days: int.parse(period)));
                  final totals = <String, int>{
                    'cash': 0, 'card': 0, 'credit': 0, 'other': 0,
                  };
                  for (final doc in trades.data!.docs) {
                    final trade = doc.data();
                    if (trade['type'] != 'sale') continue;
                    final date = (trade['createdAt'] as Timestamp?)?.toDate();
                    if (since != null && (date == null || date.isBefore(since))) continue;
                    final method = trade['paymentMethod']?.toString() ?? '';
                    final key = totals.containsKey(method) ? method : 'other';
                    totals[key] = totals[key]! +
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
    child: Text('Rapor verisi alınamadı: $error',
      style: const TextStyle(color: Color(0xFFB73232))));

  Widget _period(String code, String text) => ChoiceChip(
    label: Text(text), selected: period == code,
    onSelected: (_) => setState(() => period = code),
  );

  Future<void> _copyReport(BuildContext context, ErpMetrics metrics) async {
    final days = metrics.byDay.keys.toList()..sort();
    final csv = erpCsv([
      ['StokPilot Yönetim Raporu', period == 'all' ? 'Tüm zamanlar' : 'Son $period gün'],
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
      ...days.map((d) => [
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
        metrics.byDay[d] ?? 0,
      ]),
      [],
      ['Ürün', 'Satılan miktar (x1000)', 'Net satış (kuruş)'],
      ...metrics.topProducts.map((p) => [p.name, p.quantityMilli, p.netMinor]),
    ]);
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) notify(context, 'Rapor CSV olarak panoya kopyalandı.');
  }

  Widget _body(BuildContext context, ErpMetrics m,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> warnings,
      Map<String, int> paymentTotals) {
    final periodName = period == 'all' ? 'Tüm dönem' : 'Son $period gün';
    final sortedDates = m.byDay.keys.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DataPanel(child: LayoutBuilder(builder: (context, size) {
        final title = Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finansal kontrol paneli', style: Theme.of(context)
              .textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('$periodName • Veriler Firestore kayıtlarından hesaplanır',
              style: const TextStyle(color: muted, fontSize: 12)),
          ]);
        final export = OutlinedButton.icon(
          onPressed: () => _copyReport(context, m),
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          label: const Text('CSV kopyala'),
        );
        if (size.maxWidth < 470) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 12), export]);
        }
        return Row(children: [Expanded(child: title), export]);
      })),
      const SizedBox(height: 14),
      _metricGrid([
        MetricCard(title: 'Satış cirosu (KDV dahil)', value: money(m.salesGrossMinor),
          icon: Icons.trending_up_rounded, subtext: '${m.saleCount} satış işlemi'),
        MetricCard(title: 'Alış toplamı (KDV dahil)', value: money(m.purchasesGrossMinor),
          icon: Icons.shopping_cart_outlined, subtext: '${m.purchaseCount} alış işlemi'),
        MetricCard(title: 'Satış tahsilatı', value: money(m.salesPaidMinor),
          icon: Icons.payments_outlined, subtext: 'Dönem satışlarında kaydedilen ödeme'),
        MetricCard(title: 'Satış açık tutarı', value: money(m.outstandingSalesMinor),
          icon: Icons.pending_actions_outlined, subtext: 'Dönem satışlarından ilk kalan tutar'),
        MetricCard(title: 'Güncel stok maliyeti', value: money(m.inventoryCostMinor),
          icon: Icons.warehouse_outlined, subtext: 'Güncel miktar × son tanımlı alış fiyatı'),
        MetricCard(title: 'Cari alacak / borç',
          value: '${money(m.receivableMinor)} / ${money(m.payableMinor)}',
          icon: Icons.account_balance_wallet_outlined,
          subtext: 'Güncel cari bakiyeler • tüm zamanlar'),
      ]),
      const SizedBox(height: 14),
      DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(title: 'Ödeme yöntemleri',
            subtitle: 'Seçilen dönemde ödeme tiplerine göre satış hacmi'),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _paymentSummary('Nakit', paymentTotals['cash'] ?? 0,
              Icons.payments_outlined),
            _paymentSummary('Kart', paymentTotals['card'] ?? 0,
              Icons.credit_card_outlined),
            _paymentSummary('Veresiye', paymentTotals['credit'] ?? 0,
              Icons.receipt_long_outlined),
            if ((paymentTotals['other'] ?? 0) > 0)
              _paymentSummary('Eski kayıtlar', paymentTotals['other'] ?? 0,
                Icons.history),
          ]),
          const SizedBox(height: 6),
          const Text('Buradaki tutarlar satış toplamıdır. Veresiye, tahsilat anlamına gelmez.',
            style: TextStyle(color: muted, fontSize: 11)),
        ])),
      const SizedBox(height: 14),
      DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(title: 'Satış eğilimi',
            subtitle: 'Günlük KDV dahil satış hacmi'),
          const SizedBox(height: 14),
          if (sortedDates.length < 2)
            const BlankState(title: 'Grafik için veri bekleniyor',
              message: 'En az iki ayrı günde satış kaydı oluşturulduğunda grafik görünür.',
              icon: Icons.show_chart_rounded)
          else SizedBox(height: 215, child: LineChart(LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [LineChartBarData(
              spots: List.generate(sortedDates.length, (i) =>
                FlSpot(i.toDouble(), (m.byDay[sortedDates[i]] ?? 0) / 100)),
              color: green,
              barWidth: 3,
              isCurved: false,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true,
                color: softGreen.withValues(alpha: .65)),
            )],
          ))),
        ])),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, bounds) {
        final summaries = [
          _vatPanel(m),
          _topProducts(m),
        ];
        if (bounds.maxWidth < 820) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summaries[0], const SizedBox(height: 14), summaries[1]]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: summaries[0]), const SizedBox(width: 14),
            Expanded(child: summaries[1])]);
      }),
      const SizedBox(height: 14),
      DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(title: 'Kritik stok aksiyon listesi',
            subtitle: '${m.lowStockCount} kritik • ${m.emptyStockCount} tükenen aktif ürün'),
          const SizedBox(height: 10),
          if (warnings.isEmpty)
            const BlankState(title: 'Kritik stok yok',
              message: 'Aktif ürünlerin stok seviyeleri tanımlı eşiklerin üzerinde.',
              icon: Icons.task_alt_rounded),
          ...warnings.take(10).map((doc) {
            final product = doc.data();
            final name = (product['name'] ?? 'Ürün').toString();
            final stock = (product['stockMilli'] as num?)?.toInt() ?? 0;
            final min = (product['minStockMilli'] as num?)?.toInt() ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_rounded, color: amber),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Kritik eşik: ${quantity(min)}'),
              trailing: Text(quantity(stock),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            );
          }),
          if (warnings.length > 10)
            Text('Diğer ${warnings.length - 10} kritik ürün stok listesindedir.',
              style: const TextStyle(color: muted)),
        ])),
      const SizedBox(height: 14),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('Bilgilendirme: Bu ekran resmî fatura, muhasebe defteri veya '
          'KDV beyannamesi değildir. Dönem tahsilatı yalnızca işlemin kaydı '
          'sırasında girilen ödemeyi içerir; sonradan yapılan cari tahsilatlar '
          'ayrı kayıtlardır. Satış ile alış farkı kâr anlamına gelmez.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
      ),
    ]);
  }

  Widget _paymentSummary(String method, int amount, IconData symbol) =>
    Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: canvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(symbol, size: 17, color: green),
          const SizedBox(width: 7),
          Text(method, style: const TextStyle(
            fontSize: 12, color: muted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text(money(amount), style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
      ]),
    );

  Widget _metricGrid(List<Widget> cards) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 610 ? 2 : 1;
      final width = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final card in cards) SizedBox(width: width, child: card),
      ]);
    },
  );

  Widget _vatPanel(ErpMetrics metrics) => DataPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading(title: 'KDV görünümü',
        subtitle: 'Kayıtlardan hesaplanan, beyan yerine geçmeyen tutarlar'),
      const SizedBox(height: 12),
      _summaryRow('Satış KDV', money(metrics.outputVatMinor)),
      _summaryRow('Alış KDV', money(metrics.inputVatMinor)),
      const Divider(),
      _summaryRow('Fark', money(metrics.outputVatMinor - metrics.inputVatMinor),
        highlighted: true),
      const SizedBox(height: 10),
      _summaryRow('Ortalama satış', money(metrics.averageSaleMinor)),
    ]),
  );

  Widget _topProducts(ErpMetrics metrics) => DataPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading(title: 'En çok ciro getiren ürünler',
        subtitle: 'KDV hariç satılan kalemlerden hesaplanır'),
      const SizedBox(height: 10),
      if (metrics.topProducts.isEmpty)
        const BlankState(title: 'Satış kalemi yok',
          message: 'Satış yaptıkça ürün sıralaması burada görünür.',
          icon: Icons.bar_chart_rounded),
      ...metrics.topProducts.take(6).toList().asMap().entries.map((entry) {
        final item = entry.value;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            SizedBox(width: 26, child: Text('${entry.key + 1}.',
              style: const TextStyle(color: green, fontWeight: FontWeight.bold))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Miktar: ${quantity(item.quantityMilli)}',
                  style: const TextStyle(color: muted, fontSize: 12)),
              ])),
            const SizedBox(width: 5),
            Text(money(item.netMinor),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        );
      }),
    ]),
  );

  Widget _summaryRow(String title, String value, {bool highlighted = false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(color: muted))),
        Text(value, style: TextStyle(
          color: highlighted ? green : ink,
          fontWeight: FontWeight.w900)),
      ]),
    );
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class ReportsPage extends StatefulWidget { const ReportsPage({super.key}); @override State<ReportsPage> createState() => _ReportsPageState(); }
class _ReportsPageState extends State<ReportsPage> {
  String period = '30';
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const PageTitle(title: 'Satış ve alış raporları', subtitle: 'İşlem performansı, vergi toplamları ve cari riskler.'),
    Wrap(spacing: 8, children: [
      ChoiceChip(label: const Text('Son 7 gün'), selected: period == '7', onSelected: (_) => setState(() => period = '7')),
      ChoiceChip(label: const Text('Son 30 gün'), selected: period == '30', onSelected: (_) => setState(() => period = '30')),
      ChoiceChip(label: const Text('Son 90 gün'), selected: period == '90', onSelected: (_) => setState(() => period = '90')),
      ChoiceChip(label: const Text('Tüm zamanlar'), selected: period == 'all', onSelected: (_) => setState(() => period = 'all')),
    ]), const SizedBox(height: 16),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: AppApi.instance.watch('trades'), builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator();
      final now = DateTime.now();
      final transactions = snap.data!.docs.where((d) {
        if (period == 'all') return true;
        final dt = (d.data()['createdAt'] as Timestamp?)?.toDate();
        return dt != null && dt.isAfter(now.subtract(Duration(days: int.parse(period))));
      }).toList();
      int saleTotal = 0, purchaseTotal = 0, vatCollected = 0, vatPaid = 0, saleCount = 0;
      final byDay = <DateTime,int>{};
      for (final d in transactions) {
        final m = d.data(); final total = (m['totalMinor'] ?? 0) as int, tax = (m['taxMinor'] ?? 0) as int;
        if (m['type'] == 'sale') {
          saleTotal += total; vatCollected += tax; saleCount++;
          final date = (m['createdAt'] as Timestamp?)?.toDate();
          if (date != null) { final day = DateTime(date.year, date.month, date.day); byDay[day] = (byDay[day] ?? 0) + total; }
        } else { purchaseTotal += total; vatPaid += tax; }
      }
      return Column(children: [
        LayoutBuilder(builder: (ctx, box) {
          final cols = box.maxWidth > 980 ? 4 : (box.maxWidth > 520 ? 2 : 1), w = (box.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: w, child: MetricCard(title: 'Satış cirosu', value: money(saleTotal), icon: Icons.trending_up)),
            SizedBox(width: w, child: MetricCard(title: 'Alış toplamı', value: money(purchaseTotal), icon: Icons.shopping_cart_outlined)),
            SizedBox(width: w, child: MetricCard(title: 'Hesaplanan satış KDV', value: money(vatCollected), icon: Icons.receipt_long)),
            SizedBox(width: w, child: MetricCard(title: 'Alış KDV', value: money(vatPaid), icon: Icons.account_balance_outlined)),
          ]);
        }),
        const SizedBox(height: 16), if (byDay.isNotEmpty) DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Günlük satış grafiği', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 20),
          SizedBox(height: 190, child: LineChart(LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
            lineBarsData: [LineChartBarData(spots: (() {
              final dates = byDay.keys.toList()..sort();
              return List<FlSpot>.generate(dates.length, (i) => FlSpot(i.toDouble(), (byDay[dates[i]] ?? 0).toDouble() / 100));
            })(), isCurved: true, color: green, barWidth: 3, dotData: const FlDotData(show: false))],
          ))),
        ])),
        const SizedBox(height: 16), DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dönem özeti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), const SizedBox(height: 10),
          ListTile(title: const Text('Satış işlem adedi'), trailing: Text('$saleCount')),
          ListTile(title: const Text('Ortalama satış tutarı'), trailing: Text(money(saleCount == 0 ? 0 : (saleTotal / saleCount).round()))),
          ListTile(title: const Text('Satış - alış farkı'), subtitle: const Text('Kâr hesabı değildir; stok maliyeti ve giderler dahil değildir.'), trailing: Text(money(saleTotal - purchaseTotal))),
          ListTile(title: const Text('Satış KDV - alış KDV farkı'), subtitle: const Text('Resmî vergi beyanı yerine geçmez.'), trailing: Text(money(vatCollected - vatPaid))),
        ])),
        const SizedBox(height: 16), DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Satış günleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 10),
          if (byDay.isEmpty) const Text('Bu dönemde satış yok.'),
          ...((byDay.keys.toList()..sort((a,b) => b.compareTo(a))).take(20)).map((date) => ListTile(contentPadding: EdgeInsets.zero,
            title: Text('${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'), trailing: Text(money(byDay[date] ?? 0)))),
        ])),
      ]);
    }),
  ]);
}

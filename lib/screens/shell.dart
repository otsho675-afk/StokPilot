import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../services/billing.dart';
import '../widgets/ui.dart';
import 'products_page.dart';
import 'contacts_page.dart';
import 'trades_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget { const MainShell({super.key}); @override State<MainShell> createState() => _MainShellState(); }
class _MainShellState extends State<MainShell> {
  int selected = 0;
  final names = ['Genel Bakış', 'Ürünler', 'Satış', 'Alış', 'Cariler', 'Raporlar', 'Ayarlar'];
  final icons = [Icons.space_dashboard_outlined, Icons.inventory_2_outlined, Icons.point_of_sale_outlined, Icons.shopping_cart_outlined, Icons.people_outline, Icons.bar_chart_outlined, Icons.tune_outlined];
  Widget screen() => switch (selected) {
    0 => const OverviewPage(), 1 => const ProductsPage(), 2 => const TradesPage(type: 'sale'),
    3 => const TradesPage(type: 'purchase'), 4 => const ContactsPage(), 5 => const ReportsPage(), _ => const SettingsPage(),
  };
  Widget navItems({bool expanded = false}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(21, 28, 12, 26), child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_2_rounded, color: Colors.white)),
      const SizedBox(width: 12), const Text('StokPilot', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
    ])),
    ...List.generate(names.length, (i) => Padding(padding: const EdgeInsets.fromLTRB(12, 3, 12, 3), child: ListTile(
      leading: Icon(icons[i], color: selected == i ? ink : const Color(0xFFA5B5B9)),
      title: Text(names[i], style: TextStyle(color: selected == i ? ink : const Color(0xFFD5E1E2), fontWeight: selected == i ? FontWeight.bold : FontWeight.w500)),
      selected: selected == i, selectedTileColor: const Color(0xFFE5F7EF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      onTap: () { setState(() => selected = i); if (!expanded) Navigator.of(context).maybePop(); },
    ))),
    const Spacer(),
    Padding(padding: const EdgeInsets.all(14), child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white), icon: const Icon(Icons.logout), label: const Text('Çıkış yap'),
      onPressed: () async { await BillingService.instance.logout(); await FirebaseAuth.instance.signOut(); },
    )),
  ]);
  @override Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.entitlement(),
    builder: (context, state) {
      if (state.hasError) return Scaffold(body: Center(child: Text('Abonelik bilgisi alınamadı: ${state.error}')));
      if (!state.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return LayoutBuilder(builder: (context, constraint) {
        final desktop = constraint.maxWidth >= 900;
        return Scaffold(
          drawer: desktop ? null : Drawer(backgroundColor: ink, child: SafeArea(child: navItems())),
          body: Row(children: [
            if (desktop) SizedBox(width: 252, child: ColoredBox(color: ink, child: SafeArea(child: navItems(expanded: true)))),
            Expanded(child: SafeArea(child: Column(children: [
              if (!desktop) Builder(builder: (ctx) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: Row(children: [
                IconButton(onPressed: () => Scaffold.of(ctx).openDrawer(), icon: const Icon(Icons.menu)),
                const Text('StokPilot', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink)),
                const Spacer(),
                TextButton.icon(onPressed: () => setState(() => selected = 6), icon: const Icon(Icons.settings_outlined), label: const Text('Ayarlar')),
              ]))),
              Expanded(child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 16, vertical: desktop ? 32 : 12), child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: screen())))),
            ]))),
          ]),
          bottomNavigationBar: desktop ? null : NavigationBar(height: 68, selectedIndex: [0,1,2,4].contains(selected) ? [0,1,2,4].indexOf(selected) : 3,
            onDestinationSelected: (index) => setState(() => selected = [0,1,2,4][index]), destinations: const [
              NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), label: 'Panel'),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stok'),
              NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'Satış'),
              NavigationDestination(icon: Icon(Icons.people_outline), label: 'Cariler'),
            ]),
        );
      });
    },
  );
}
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const PageTitle(title: 'İşletme özeti', subtitle: 'Stok, satış ve cari durumunuzu canlı izleyin.'),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: AppApi.instance.watch('products'), builder: (context, productState) {
      if (!productState.hasData) return const LinearProgressIndicator();
      final products = productState.data!.docs;
      final low = products.where((p) => ((p.data()['stockMilli'] ?? 0) as num).toInt() <= ((p.data()['minStockMilli'] ?? 0) as num).toInt()).toList();
      final stockValue = products.fold<int>(0, (acc, p) => acc + (((p.data()['stockMilli'] ?? 0) as num) * ((p.data()['purchasePriceMinor'] ?? 0) as num) / 1000).round());
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: AppApi.instance.watch('contacts'), builder: (context, contactState) {
        final contacts = contactState.data?.docs ?? [];
        final receivable = contacts.fold<int>(0, (acc, c) { final b = (c.data()['balanceMinor'] ?? 0) as int; return acc + (b > 0 ? b : 0); });
        final payable = contacts.fold<int>(0, (acc, c) { final b = (c.data()['balanceMinor'] ?? 0) as int; return acc + (b < 0 ? -b : 0); });
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (ctx, cs) { final columns = cs.maxWidth > 1050 ? 4 : (cs.maxWidth > 530 ? 2 : 1); final width = (cs.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              SizedBox(width: width, child: MetricCard(title: 'Toplam ürün', value: '${products.length}', icon: Icons.inventory_2_outlined)),
              SizedBox(width: width, child: MetricCard(title: 'Stok maliyeti', value: money(stockValue), icon: Icons.warehouse_outlined)),
              SizedBox(width: width, child: MetricCard(title: 'Alacaklar', value: money(receivable), icon: Icons.trending_up)),
              SizedBox(width: width, child: MetricCard(title: 'Borçlar', value: money(payable), icon: Icons.trending_down)),
            ]);
          }),
          const SizedBox(height: 24), DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.warning_amber_outlined, color: Color(0xFFCC7E10)), const SizedBox(width: 8), Text('Kritik stok (${low.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 9), if (low.isEmpty) const Text('Kritik seviyeye düşen ürün yok.'),
            ...low.take(12).map((p) => ListTile(contentPadding: EdgeInsets.zero, title: Text(p.data()['name'] ?? ''), subtitle: Text('Eşik: ${quantity(((p.data()['minStockMilli'] ?? 0) as num).toInt())}'), trailing: Text(quantity(((p.data()['stockMilli'] ?? 0) as num).toInt()), style: const TextStyle(fontWeight: FontWeight.bold))))
          ])),
        ]);
      });
    }),
  ]);
}

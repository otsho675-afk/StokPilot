import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/app_api.dart';
import '../services/billing.dart';
import '../widgets/ui.dart';
import 'products_page.dart';
import 'contacts_page.dart';
import 'trades_page.dart';
import 'reports_page.dart';
import 'operations_page.dart';
import 'finance_page.dart';
import 'settings_page.dart';
import 'overview_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  static const names = [
    'Genel Bakış',
    'Ürünler',
    'Satış',
    'Alış',
    'Müşteri carileri',
    'Tedarikçiler',
    'Finans',
    'Raporlar',
    'ERP İşlemleri',
    'Ayarlar',
  ];
  static const icons = [
    Icons.space_dashboard_rounded,
    Icons.inventory_2_outlined,
    Icons.point_of_sale_rounded,
    Icons.shopping_bag_outlined,
    Icons.people_alt_outlined,
    Icons.local_shipping_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.insert_chart_outlined,
    Icons.assignment_outlined,
    Icons.tune_rounded,
  ];
  static const mobileTabs = [0, 1, 2, 4];
  static const _groups = ['GENEL', 'STOK & TİCARET', 'CARİ HESAPLAR', 'YÖNETİM & SİSTEM'];
  static const _groupStarts = [0, 1, 4, 6];


  void navigate(int index) {
    if (selected != index && mounted) setState(() => selected = index);
  }

  Widget screen() => switch (selected) {
    0 => OverviewPage(onNavigate: navigate),
    1 => const ProductsPage(),
    2 => const TradesPage(type: 'sale'),
    3 => const TradesPage(type: 'purchase'),
    4 => const ContactsPage(kind: 'customer'),
    5 => const ContactsPage(kind: 'supplier'),
    6 => const FinancePage(),
    7 => const ReportsPage(),
    8 => const OperationsPage(),
    _ => const SettingsPage(),
  };

  Widget _brand({bool compact = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 40 : 44,
        height: compact ? 40 : 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1FBE96), Color(0xFF087E78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(
          Icons.inventory_2_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 11),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'StokPilot',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              Text(
                'İşletme yönetimi',
                style: TextStyle(color: Color(0xFF9BB7BA), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _desktopHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 17),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                names[selected],
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'StokPilot · İşletme yönetim paneli',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Yeni satış',
          child: FilledButton.icon(
            onPressed: () => navigate(2),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Hızlı satış'),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => navigate(9),
          tooltip: 'Ayarlar',
          icon: const Icon(Icons.settings_outlined, color: muted),
        ),
      ],
    ),
  );

  Future<void> _signOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.isAnonymous == true) {
      if (!await confirm(
        context,
        'Misafir hesabından çık',
        'Google veya Apple hesabına bağlanmadıysan mevcut misafir verilerine yeniden erişemeyebilirsin. Yine de çıkış yapılsın mı?',
      )) {
        return;
      }
    }
    await BillingService.instance.logout();
    await FirebaseAuth.instance.signOut();
  }

  Widget _sidebar({required bool condensed}) => ColoredBox(
    color: const Color(0xFF102338),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(condensed ? 16 : 22, 26, 12, 24),
            child: _brand(compact: condensed),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (!condensed)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 0, 14),
                    child: Text(
                      'ÇALIŞMA ALANI',
                      style: TextStyle(
                        color: Color(0xFF8FAAC2),
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ...List.generate(names.length, (i) {
                  final active = selected == i;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!condensed && _groupStarts.contains(i))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 22, 8, 10),
                          child: Text(
                            _groups[_groupStarts.indexOf(i)],
                            style: const TextStyle(
                              color: Color(0xFF8FAAC2),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                      Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Tooltip(
                      message: condensed ? names[i] : '',
                      child: Material(
                        color:
                            active
                                ? const Color(0xFF21405B)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => navigate(i),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: condensed ? 0 : 14,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  condensed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  icons[i],
                                  size: 21,
                                  color:
                                      active ? const Color(0xFF58E0BD) : const Color(0xFFB8C9DC),
                                ),
                                if (!condensed) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      names[i],
                                      style: TextStyle(
                                        fontWeight:
                                            active
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                        color:
                                            active
                                                ? Colors.white
                                                : const Color(0xFFE4ECF6),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                    ],
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child:
                condensed
                    ? IconButton(
                      tooltip: 'Çıkış yap',
                      onPressed: _signOut,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                      ),
                    )
                    : OutlinedButton.icon(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF405A72)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Güvenli çıkış'),
                    ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.entitlement(),
    builder: (context, state) {
      if (state.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Abonelik bilgisi alınamadı: ${state.error}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      if (!state.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1110;
          final rail = c.maxWidth >= 760 && !wide;
          final showSide = wide || rail;
          final mobile = !showSide;
          return Scaffold(
            key: _scaffoldKey,
            drawer:
                mobile
                    ? Drawer(
                      backgroundColor: const Color(0xFF102338),
                      child: SafeArea(
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: _brand(),
                            ),
                            ...List.generate(
                              names.length,
                              (i) => ListTile(
                                leading: Icon(
                                  icons[i],
                                  color:
                                      selected == i
                                          ? const Color(0xFFFFFFFF)
                                          : Colors.white70,
                                ),
                                title: Text(
                                  names[i],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                selected: selected == i,
                                selectedTileColor: const Color(0xFF21405B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onTap: () {
                                  navigate(i);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                            const Divider(color: Colors.white24),
                            ListTile(
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                              ),
                              title: const Text(
                                'Çıkış yap',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await _signOut();
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                    : null,
            body: Row(
              children: [
                if (showSide)
                  SizedBox(
                    width: wide ? 264 : 76,
                    child: _sidebar(condensed: rail),
                  ),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      children: [
                        if (!mobile) _desktopHeader(),
                        if (mobile)
                          Builder(
                            builder:
                                (inner) => Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Menüyü aç',
                                        icon: const Icon(Icons.menu_rounded),
                                        onPressed:
                                            () =>
                                                Scaffold.of(inner).openDrawer(),
                                      ),
                                      const Icon(
                                        Icons.inventory_2_rounded,
                                        color: green,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'StokPilot',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: ink,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Alış kaydı',
                                        onPressed: () => navigate(3),
                                        icon: const Icon(
                                          Icons.add_shopping_cart_outlined,
                                          color: green,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Ayarlar',
                                        onPressed: () => navigate(9),
                                        icon: const Icon(
                                          Icons.settings_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              wide ? 30 : 15,
                              24,
                              wide ? 30 : 15,
                              mobile ? 20 : 30,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1240,
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey(selected),
                                  child: screen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar:
                mobile
                    ? NavigationBar(
                      height: 68,
                      backgroundColor: Colors.white,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      selectedIndex:
                          mobileTabs.contains(selected)
                              ? mobileTabs.indexOf(selected)
                              : 4,
                      onDestinationSelected: (index) {
                        if (index == 4) {
                          _scaffoldKey.currentState?.openDrawer();
                        } else {
                          navigate(mobileTabs[index]);
                        }
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.space_dashboard_outlined),
                          selectedIcon: Icon(Icons.space_dashboard_rounded),
                          label: 'Panel',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2_rounded),
                          label: 'Stok',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.point_of_sale_outlined),
                          selectedIcon: Icon(Icons.point_of_sale_rounded),
                          label: 'Satış',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people_alt),
                          label: 'Cariler',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.menu_rounded),
                          label: 'Menü',
                        ),
                      ],
                    )
                    : null,
          );
        },
      );
    },
  );
}

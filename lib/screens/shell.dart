import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/global_search.dart';
import '../services/app_api.dart';
import '../services/billing.dart';
import '../widgets/inventory_alert_button.dart';
import '../widgets/ui.dart';
import 'catalog_management_page.dart';
import 'contacts_page.dart';
import 'finance_page.dart';
import 'global_search_dialog.dart';
import 'operations_page.dart';
import 'overview_page.dart';
import 'products_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'trades_page.dart';

/// One navigation system for desktop, tablet and mobile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  bool sidebarCollapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const names = [
    'Genel Bakış',
    'Ürünler',
    'Satış',
    'Alış',
    'Müşteriler',
    'Tedarikçiler',
    'Finans',
    'Raporlar',
    'İşlem geçmişi',
    'Kategori ve Birimler',
    'Ayarlar',
  ];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.inventory_2_outlined,
    Icons.point_of_sale_rounded,
    Icons.shopping_bag_outlined,
    Icons.people_outline_rounded,
    Icons.local_shipping_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.bar_chart_rounded,
    Icons.receipt_long_outlined,
    Icons.category_outlined,
    Icons.tune_rounded,
  ];
  static const sectionNames = [
    'ÇALIŞMA ALANI',
    'STOK VE İŞLEMLER',
    'CARİ YÖNETİMİ',
    'RAPOR VE AYARLAR',
  ];
  static const sectionStarts = [0, 1, 4, 6];
  static const mobileTabs = [0, 1, 2, 4];

  void navigate(int index) {
    if (selected != index && mounted) setState(() => selected = index);
  }

  Future<void> _openSearch() async {
    final selection = await showDialog<SearchSelection>(
      context: context,
      builder: (_) => const GlobalSearchDialog(),
    );
    if (!mounted || selection == null) return;
    switch (selection.item.kind) {
      case SearchKind.product:
        navigate(1);
        if (selection.document != null) {
          await productDialog(context, item: selection.document);
        }
      case SearchKind.customer:
      case SearchKind.supplier:
        navigate(selection.item.kind == SearchKind.supplier ? 5 : 4);
        if (selection.document != null) {
          await contactDialog(context, item: selection.document);
        }
      case SearchKind.sale:
        navigate(2);
        if (selection.document != null) {
          showTradeDetails(context, selection.document!.data());
        }
      case SearchKind.purchase:
        navigate(3);
        if (selection.document != null) {
          showTradeDetails(context, selection.document!.data());
        }
    }
  }

  void _openAlert(InventoryAlertSelection selection) {
    if (!mounted) return;
    navigate(1);
    if (selection.alert.kind == 'stock') {
      stockDialog(context, selection.product);
    } else {
      productDialog(context, item: selection.product);
    }
  }

  Widget screen() => switch (selected) {
    0 => OverviewPage(onNavigate: navigate),
    1 => const ProductsPage(),
    2 => const TradesPage(key: ValueKey('sale-trade'), type: 'sale'),
    3 => const TradesPage(key: ValueKey('purchase-trade'), type: 'purchase'),
    4 => const ContactsPage(kind: 'customer'),
    5 => const ContactsPage(kind: 'supplier'),
    6 => const FinancePage(),
    7 => const ReportsPage(),
    8 => const OperationsPage(),
    9 => const CatalogManagementPage(),
    _ => const SettingsPage(),
  };

  Future<void> _signOut() async {
    final user = AppApi.instance.auth.currentUser;
    if (user?.isAnonymous == true) {
      if (!await confirm(
        context,
        'Misafir hesabından çık',
        'Hesabını Google veya Apple ile bağlamadıysan misafir verilerine tekrar erişemeyebilirsin. Çıkış yapılsın mı?',
      )) {
        return;
      }
    }
    await BillingService.instance.logout();
    await AppApi.instance.auth.signOut();
  }

  Widget _brand({required bool compact}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [green, Color(0xFF302987)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.layers_rounded, color: Colors.white, size: 22),
      ),
      if (!compact) ...[
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'StokPilot',
              style: TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
              ),
            ),
            Text(
              'İŞLETME PLATFORMU',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.15,
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _navItem(int index, {required bool compact, required bool drawer}) {
    final active = selected == index;
    final child = InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () {
        navigate(index);
        if (drawer) Navigator.of(context).pop();
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: active ? softGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: active ? Border.all(color: line) : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
        child: Row(
          mainAxisAlignment:
              compact ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icons[index],
              size: 19,
              color: active ? green : const Color(0xFF718095),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  names[index],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? green : ink,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: green,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: compact ? Tooltip(message: names[index], child: child) : child,
    );
  }

  Widget _sidebar({required bool compact, bool drawer = false}) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: line)),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 13 : 18,
              18,
              compact ? 13 : 10,
              15,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (compact)
                  Expanded(child: Center(child: _brand(compact: true)))
                else
                  Expanded(child: _brand(compact: false)),
                if (!compact && !drawer)
                  IconButton(
                    onPressed: () => setState(() => sidebarCollapsed = true),
                    tooltip: 'Menüyü daralt',
                    icon: const Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      size: 19,
                      color: muted,
                    ),
                  ),
              ],
            ),
          ),
          if (compact && !drawer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IconButton(
                tooltip: 'Menüyü genişlet',
                onPressed: () => setState(() => sidebarCollapsed = false),
                icon: const Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  color: muted,
                  size: 19,
                ),
              ),
            ),
          const Divider(height: 1, color: line),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 9 : 13,
                10,
                compact ? 9 : 13,
                8,
              ),
              children: [
                for (var i = 0; i < names.length; i++) ...[
                  if (!compact && sectionStarts.contains(i))
                    Padding(
                      padding: EdgeInsets.fromLTRB(11, i == 0 ? 5 : 20, 6, 8),
                      child: Text(
                        sectionNames[sectionStarts.indexOf(i)],
                        style: const TextStyle(
                          color: Color(0xFF8B97A7),
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (compact && sectionStarts.contains(i) && i != 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: line),
                    ),
                  _navItem(i, compact: compact, drawer: drawer),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: line),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: 12,
            ),
            child:
                compact
                    ? IconButton(
                      tooltip: 'Güvenli çıkış',
                      onPressed:
                          drawer
                              ? () async {
                                Navigator.of(context).pop();
                                await _signOut();
                              }
                              : _signOut,
                      icon: const Icon(Icons.logout_rounded, color: muted),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: softGreen,
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: green,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Çalışma hesabı',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                  Text(
                                    AppApi.instance.auth.currentUser?.email ??
                                        'Oturum açık',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed:
                              drawer
                                  ? () async {
                                    Navigator.of(context).pop();
                                    await _signOut();
                                  }
                                  : _signOut,
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Güvenli çıkış'),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: muted,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    ),
  );

  Widget _desktopHeader() => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 30),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icons[selected], color: green, size: 19),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                names[selected],
                style: const TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Çalışma alanı / StokPilot',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tüm kayıtlarda ara',
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded, color: muted),
        ),
        InventoryAlertButton(onSelected: _openAlert),
        IconButton(
          tooltip: 'Ayarlar',
          onPressed: () => navigate(10),
          icon: const Icon(Icons.settings_outlined, color: muted),
        ),
      ],
    ),
  );

  Widget _mobileHeader() => Container(
    height: 60,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        const SizedBox(width: 10),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.layers_rounded, color: green, size: 17),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            names[selected],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tüm kayıtlarda ara',
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded, color: ink),
        ),
        InventoryAlertButton(onSelected: _openAlert),
        IconButton(
          tooltip: 'Ayarlar',
          onPressed: () => navigate(10),
          icon: const Icon(Icons.settings_outlined, color: muted),
        ),
      ],
    ),
  );

  Widget _bottomNav() => NavigationBar(
    height: 76,
    backgroundColor: Colors.white,
    elevation: 0,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    selectedIndex:
        mobileTabs.contains(selected) ? mobileTabs.indexOf(selected) : 4,
    onDestinationSelected: (index) {
      if (index == 4) {
        _scaffoldKey.currentState?.openDrawer();
      } else {
        navigate(mobileTabs[index]);
      }
    },
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
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
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Müşteriler',
      ),
      NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'Menü'),
    ],
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
            child: Text('Abonelik bilgisi alınamadı: ${state.error}'),
          ),
        );
      }
      if (!state.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return LayoutBuilder(
        builder: (context, bounds) {
          final desktop = bounds.maxWidth >= 1100;
          final showSide = bounds.maxWidth >= 760;
          final compact = !desktop || sidebarCollapsed;
          final mobile = !showSide;
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: canvas,
            drawer:
                mobile
                    ? Drawer(
                      width: 292,
                      backgroundColor: Colors.white,
                      child: _sidebar(compact: false, drawer: true),
                    )
                    : null,
            body: Row(
              children: [
                if (showSide)
                  SizedBox(
                    width: compact ? 76 : 262,
                    child: _sidebar(compact: compact),
                  ),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      children: [
                        if (mobile) _mobileHeader() else _desktopHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              mobile ? (bounds.maxWidth < 370 ? 10 : 15) : 28,
                              mobile ? 14 : 26,
                              mobile ? (bounds.maxWidth < 370 ? 10 : 15) : 28,
                              30,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1320,
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
            bottomNavigationBar: mobile ? _bottomNav() : null,
          );
        },
      );
    },
  );
}

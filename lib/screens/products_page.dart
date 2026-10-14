import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/smart_inventory.dart';
import '../core/sales_tools.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';
import 'paywall_page.dart';
import 'product_editor_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String query = '';
  String categoryFilter = '';
  String stockFilter = 'all';
  String sortBy = 'name';
  int currentPage = 0;
  int pageSize = 20;
  bool showPurchasePrice = false;
  bool advancedFilters = false;
  double? minimumPrice;
  double? maximumPrice;
  final minPriceInput = TextEditingController();
  final maxPriceInput = TextEditingController();
  final search = TextEditingController();
  bool _openingProduct = false;

  @override
  void dispose() {
    search.dispose();
    minPriceInput.dispose();
    maxPriceInput.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    if (_openingProduct) return;
    setState(() => _openingProduct = true);
    try {
      final ws = await AppApi.instance.workspace.get();
      final ent =
          await AppApi.instance.collection('entitlements').doc('current').get();
      final e = ent.data() ?? {};
      final expiry = e['expiresAt'];
      final pro =
          e['status'] == 'active' &&
          (e['source'] == 'revenuecat' ||
              (AppApi.instance.uid == 'gbw2USpZ8cNtcSyge5a2BEwJw3E3' &&
                  e['source'] == 'review')) &&
          expiry is Timestamp &&
          expiry.toDate().isAfter(DateTime.now());
      final count = (ws.data()?['productCount'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (!pro && count >= 50) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallPage()),
        );
      } else {
        await productDialog(context);
      }
    } catch (e) {
      if (mounted) {
        notify(context, 'Ürün limiti kontrol edilemedi: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _openingProduct = false);
    }
  }

  double? _markup(Map<String, dynamic> product) {
    final purchase = (product['purchasePriceMinor'] as num?)?.toInt() ?? 0;
    final sale = (product['salePriceMinor'] as num?)?.toInt() ?? 0;
    return profitMarkupPercent(purchase, sale);
  }

  bool _matches(Map<String, dynamic> m) {
    final qty = (m['stockMilli'] as num?)?.toInt() ?? 0;
    final min = (m['minStockMilli'] as num?)?.toInt() ?? 0;
    final active = m['isActive'] != false;
    final byStock = switch (stockFilter) {
      'low' => active && qty <= min,
      'empty' => active && qty <= 0,
      'inactive' => !active,
      'loss' => active && (_markup(m) ?? 1) <= 0,
      _ => true,
    };
    final entry = ProductSearchEntry(
      id: '',
      name: (m['name'] ?? '').toString(),
      sku: (m['sku'] ?? '').toString(),
      barcode: (m['barcode'] ?? '').toString(),
      stockMilli: qty,
    );
    final price = ((m['salePriceMinor'] as num?)?.toInt() ?? 0) / 100;
    return byStock &&
        (minimumPrice == null || price >= minimumPrice!) &&
        (maximumPrice == null || price <= maximumPrice!) &&
        (categoryFilter.isEmpty || m['categoryId'] == categoryFilter) &&
        productSearchScore(entry, query) >= 0;
  }

  int _compare(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final one = a.data(), two = b.data();
    switch (sortBy) {
      case 'stock':
        return ((one['stockMilli'] as num?)?.toInt() ?? 0).compareTo(
          (two['stockMilli'] as num?)?.toInt() ?? 0,
        );
      case 'markup':
        return (_markup(one) ?? double.infinity).compareTo(
          _markup(two) ?? double.infinity,
        );
      case 'price':
        return ((two['salePriceMinor'] as num?)?.toInt() ?? 0).compareTo(
          (one['salePriceMinor'] as num?)?.toInt() ?? 0,
        );
      case 'new':
        final d1 =
            (one['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final d2 =
            (two['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return d2.compareTo(d1);
      default:
        return (one['name'] ?? '').toString().toLowerCase().compareTo(
          (two['name'] ?? '').toString().toLowerCase(),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageTitle(
        title: 'Ürünler ve stoklar',
        subtitle: 'Ürünlerini ara, düzenle, kritik seviyeleri takip et.',
        action: FilledButton.icon(
          onPressed: _openingProduct ? null : _addProduct,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Yeni ürün'),
        ),
      ),
      const _InventoryAlertsPanel(),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.workspace.snapshots(),
        builder:
            (
              context,
              ws,
            ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppApi.instance.entitlement(),
              builder: (context, ent) {
                final e = ent.data?.data() ?? {};
                final expiry = e['expiresAt'];
                final pro =
                    e['status'] == 'active' &&
                    (e['source'] == 'revenuecat' ||
                        (AppApi.instance.uid ==
                                'gbw2USpZ8cNtcSyge5a2BEwJw3E3' &&
                            e['source'] == 'review')) &&
                    expiry is Timestamp &&
                    expiry.toDate().isAfter(DateTime.now());
                final count =
                    (ws.data?.data()?['productCount'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DataPanel(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final remaining = (50 - count).clamp(0, 50);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: softGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    pro
                                        ? Icons.workspace_premium_outlined
                                        : Icons.inventory_2_outlined,
                                    color: green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pro
                                            ? 'StokPilot Pro • Sınırsız ürün'
                                            : '$count / 50 ücretsiz ürün',
                                        style: const TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (!pro)
                                        Text(
                                          '$remaining ürün hakkın kaldı',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!pro && c.maxWidth > 380)
                                  TextButton.icon(
                                    onPressed:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const PaywallPage(),
                                          ),
                                        ),
                                    icon: const Icon(
                                      Icons.workspace_premium_outlined,
                                    ),
                                    label: const Text('Pro'),
                                  ),
                              ],
                            ),
                            if (!pro) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: (count / 50).clamp(0.0, 1.0),
                                  minHeight: 7,
                                  color: count >= 45 ? amber : green,
                                  backgroundColor: const Color(0xFFE5EEED),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('categories'),
        builder: (context, categories) {
          final cats = categories.data?.docs ?? [];
          final selectedCategory =
              cats.any((d) => d.id == categoryFilter) ? categoryFilter : '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DataPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final searchField = TextField(
                          controller: search,
                          textInputAction: TextInputAction.search,
                          onChanged:
                              (s) => setState(() {
                                query = s.trim();
                                currentPage = 0;
                              }),
                          decoration: InputDecoration(
                            hintText: 'Ürün adı, barkod veya stok kodu',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon:
                                query.isEmpty
                                    ? null
                                    : IconButton(
                                      tooltip: 'Aramayı temizle',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed:
                                          () => setState(() {
                                            search.clear();
                                            query = '';
                                            currentPage = 0;
                                          }),
                                    ),
                          ),
                        );
                        final category = DropdownButtonFormField<String>(
                          key: ValueKey(selectedCategory),
                          initialValue: selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tüm kategoriler'),
                            ),
                            ...cats.map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  '${d.data()['name'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged:
                              (s) => setState(() {
                                categoryFilter = s ?? '';
                                currentPage = 0;
                              }),
                        );
                        if (c.maxWidth < 560) {
                          return Column(
                            children: [
                              searchField,
                              const SizedBox(height: 10),
                              category,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 3, child: searchField),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: category),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => advancedFilters = !advancedFilters),
                      icon: Icon(advancedFilters ? Icons.tune_rounded : Icons.filter_alt_outlined),
                      label: Text(advancedFilters ? 'Gelişmiş filtreleri kapat' : 'Gelişmiş filtreler · fiyat aralığı'),
                    ),
                    if (advancedFilters) ...[
                      const SizedBox(height: 12),
                      ResponsiveFields(
                        first: TextField(
                          controller: minPriceInput,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'En düşük satış fiyatı (₺)',
                            prefixIcon: Icon(Icons.arrow_downward_rounded),
                          ),
                          onChanged: (value) => setState(() {
                            minimumPrice = double.tryParse(value.replaceAll(',', '.'));
                            currentPage = 0;
                          }),
                        ),
                        second: TextField(
                          controller: maxPriceInput,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'En yüksek satış fiyatı (₺)',
                            prefixIcon: Icon(Icons.arrow_upward_rounded),
                          ),
                          onChanged: (value) => setState(() {
                            maximumPrice = double.tryParse(value.replaceAll(',', '.'));
                            currentPage = 0;
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            minPriceInput.clear();
                            maxPriceInput.clear();
                            minimumPrice = null;
                            maximumPrice = null;
                            currentPage = 0;
                          }),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Fiyat filtresini sıfırla'),
                        ),
                      ),
                    ],
                    const Divider(height: 18),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alış fiyatı ve kâr oranını göster'),
                      subtitle: const Text('Kapalıyken maliyet bilgileri ürün kartlarında gizlenir.'),
                      value: showPurchasePrice,
                      onChanged: (v) => setState(() => showPurchasePrice = v),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _filter('all', 'Tümü', Icons.apps_rounded),
                        _filter('low', 'Kritik', Icons.warning_amber_rounded),
                        _filter(
                          'loss',
                          'Zarar riski',
                          Icons.trending_down_rounded,
                        ),
                        _filter(
                          'empty',
                          'Tükenen',
                          Icons.remove_shopping_cart_outlined,
                        ),
                        _filter(
                          'inactive',
                          'Pasif',
                          Icons.visibility_off_outlined,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Sıralama',
                          initialValue: sortBy,
                          onSelected:
                              (s) => setState(() {
                                sortBy = s;
                                currentPage = 0;
                              }),
                          itemBuilder:
                              (_) => const [
                                PopupMenuItem(
                                  value: 'name',
                                  child: Text('Ada göre (A-Z)'),
                                ),
                                PopupMenuItem(
                                  value: 'stock',
                                  child: Text('Az stok önce'),
                                ),
                                PopupMenuItem(
                                  value: 'price',
                                  child: Text('Yüksek fiyat önce'),
                                ),
                                PopupMenuItem(
                                  value: 'new',
                                  child: Text('Yeni eklenen önce'),
                                ),
                                PopupMenuItem(
                                  value: 'markup',
                                  child: Text('En düşük kâr oranı'),
                                ),
                              ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  color: green,
                                  size: 19,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Sırala',
                                  style: TextStyle(
                                    color: green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppApi.instance.watch('products'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return DataPanel(
                      child: Text('Ürünler yüklenemedi: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final filtered =
                      snapshot.data!.docs
                          .where((d) => _matches(d.data()))
                          .toList()
                        ..sort(_compare);
                  if (filtered.isEmpty) {
                    return DataPanel(
                      child: BlankState(
                        title: 'Ürün bulunamadı',
                        message:
                            query.isEmpty && stockFilter == 'all'
                                ? 'Başlamak için yeni bir ürün ekle.'
                                : 'Arama veya filtrelerini değiştirmeyi dene.',
                        icon: Icons.inventory_2_outlined,
                        action:
                            query.isEmpty && stockFilter == 'all'
                                ? FilledButton.icon(
                                  onPressed: _addProduct,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ürün ekle'),
                                )
                                : TextButton(
                                  onPressed:
                                      () => setState(() {
                                        query = '';
                                        search.clear();
                                        categoryFilter = '';
                                        stockFilter = 'all';
                                        currentPage = 0;
                                      }),
                                  child: const Text('Filtreleri temizle'),
                                ),
                      ),
                    );
                  }
                  final totalPages = (filtered.length + pageSize - 1) ~/ pageSize;
                  final page = currentPage.clamp(0, totalPages - 1);
                  final visible = filtered.skip(page * pageSize).take(pageSize).toList();
                  return DataPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeading(
                          title: 'Ürün listesi',
                          subtitle: '${filtered.length} eşleşen ürün',
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder:
                              (context, c) => Column(
                                children: [
                                  if (c.maxWidth >= 650)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: canvas,
                                        borderRadius: BorderRadius.circular(10)),
                                      child: const Row(children: [
                                        Expanded(flex: 5, child: Text('ÜRÜN BİLGİSİ',
                                          style: TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 10))),
                                        Expanded(flex: 2, child: Text('SATIŞ FİYATI',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 10))),
                                        SizedBox(width: 117, child: Text('STOK',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 10))),
                                        SizedBox(width: 82),
                                      ]),
                                    ),
                                  ...visible.map(
                                    (item) =>
                                        c.maxWidth < 650
                                            ? _mobileProduct(context, item)
                                            : _wideProduct(context, item),
                                  ),
                                ],
                              ),
                        ),
                        ListPager(
                          total: filtered.length,
                          page: page,
                          pageSize: pageSize,
                          onPageChanged: (n) => setState(() => currentPage = n),
                          onPageSizeChanged: (n) => setState(() { pageSize = n; currentPage = 0; }),
                        ),

                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ],
  );

  Widget _filter(String id, String label, IconData icon) => ChoiceChip(
    selected: stockFilter == id,
    label: Text(label),
    avatar: Icon(icon, size: 16),
    onSelected:
        (_) => setState(() {
          stockFilter = id;
          currentPage = 0;
        }),
  );

  Widget _productActions(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> p,
  ) => PopupMenuButton<String>(
    tooltip: 'Ürün işlemleri',
    onSelected: (value) {
      if (value == 'edit') productDialog(context, item: p);
      if (value == 'stock') stockDialog(context, p);
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: '${p.data()['barcode'] ?? ''}'));
        notify(context, 'Barkod kopyalandı.');
      }
    },
    itemBuilder:
        (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Ürünü düzenle')),
          const PopupMenuItem(
            value: 'stock',
            child: Text('Stok giriş / çıkış'),
          ),
          if ('${p.data()['barcode'] ?? ''}'.isNotEmpty)
            const PopupMenuItem(value: 'copy', child: Text('Barkodu kopyala')),
        ],
  );

  Widget _mobileProduct(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> p,
  ) {
    final m = p.data();
    final qty = (m['stockMilli'] as num?)?.toInt() ?? 0;
    final min = (m['minStockMilli'] as num?)?.toInt() ?? 0;
    final disabled = m['isActive'] == false;
    final alert = qty <= min;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alert ? const Color(0xFFFFF0DD) : softGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: alert ? amber : green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m['name'] ?? 'Ürün'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      Text(
                        '${m['sku'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                _productActions(context, p),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                StatusPill(
                  label: 'Stok ${quantity(qty)}',
                  color: alert ? amber : green,
                ),
                if (disabled) const StatusPill(label: 'Pasif', color: muted),
                if (showPurchasePrice && _markup(m) != null)
                  StatusPill(
                    label: 'Alışa göre %${_markup(m)!.toStringAsFixed(1)}',
                    color: _markup(m)! <= 0 ? const Color(0xFFC2574B) : green,
                  ),
                StatusPill(
                  label:
                      'KDV %${((m['taxRateBps'] ?? 0) / 100).toStringAsFixed(0)}',
                  color: ink,
                ),
              ],
            ),
            if (showPurchasePrice) ...[
              const SizedBox(height: 8),
              Text('Alış: ${money((m['purchasePriceMinor'] as num?)?.toInt() ?? 0)}', style: const TextStyle(color: muted)),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Satış ${money((m['salePriceMinor'] as num?)?.toInt() ?? 0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => stockDialog(context, p),
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Stok işlemi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideProduct(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> p,
  ) {
    final m = p.data();
    final qty = (m['stockMilli'] as num?)?.toInt() ?? 0;
    final threshold = (m['minStockMilli'] as num?)?.toInt() ?? 0;
    final alert = qty <= threshold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: alert ? const Color(0xFFF0D8B0) : line),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: alert ? const Color(0xFFFFF0DD) : softGreen,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.inventory_2_outlined, color: alert ? amber : green),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name'] ?? 'Ürün'}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Kod: ${m['sku'] ?? '—'}  ·  Barkod: ${m['barcode'] ?? '—'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 11)),
                if (showPurchasePrice) ...[
                  const SizedBox(height: 5),
                  Text('Alış: ${money((m['purchasePriceMinor'] as num?)?.toInt() ?? 0)}'
                    '${_markup(m) == null ? '' : '  ·  Kâr %${_markup(m)!.toStringAsFixed(1)}'}',
                    style: const TextStyle(color: muted, fontSize: 12)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money((m['salePriceMinor'] as num?)?.toInt() ?? 0),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: 17)),
                const Text('Satış fiyatı', style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 12),
            StatusPill(label: 'Stok ${quantity(qty)}', color: alert ? amber : green),
            IconButton(
              tooltip: 'Stok işlemi',
              onPressed: () => stockDialog(context, p),
              icon: const Icon(Icons.tune_rounded, color: green),
            ),
            _productActions(context, p),
          ],
        ),
      ),
    );
  }
}

class _InventoryAlertsPanel extends StatelessWidget {
  const _InventoryAlertsPanel();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.watch('products'),
    builder:
        (
          context,
          products,
        ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              AppApi.instance.collection('settings').doc('alerts').snapshots(),
          builder: (context, settings) {
            if (!products.hasData) return const SizedBox.shrink();
            final preference =
                settings.data?.data() ?? const <String, dynamic>{};
            final days =
                (preference['priceReminderDays'] as num?)?.toInt() ?? 45;
            final stockEnabled = preference['lowStockAlerts'] != false;
            final documents = {
              for (final doc in products.data!.docs) doc.id: doc,
            };
            final entries = products.data!.docs.map((doc) {
              final value = Map<String, dynamic>.from(doc.data());
              final date = value['priceChangedAt'] ?? value['createdAt'];
              if (date is Timestamp) value['priceChangedAt'] = date.toDate();
              return MapEntry(doc.id, value);
            });
            final alerts =
                inventoryAlerts(
                      entries,
                      now: DateTime.now(),
                      priceReminderDays: days,
                    )
                    .where((alert) => stockEnabled || alert.kind != 'stock')
                    .toList();
            if (alerts.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DataPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${alerts.length} ürün hatırlatıcısı',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ...alerts
                        .take(6)
                        .map(
                          (alert) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              alert.kind == 'stock'
                                  ? Icons.inventory_2_outlined
                                  : Icons.price_change_outlined,
                              color: alert.kind == 'stock' ? amber : green,
                            ),
                            title: Text(
                              alert.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(alert.message),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final product = documents[alert.productId];
                              if (product == null) return;
                              if (alert.kind == 'stock') {
                                stockDialog(context, product);
                              } else {
                                productDialog(context, item: product);
                              }
                            },
                          ),
                        ),
                    if (alerts.length > 6)
                      Text(
                        '${alerts.length - 6} uyarı daha',
                        style: const TextStyle(color: muted),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

Future<void> stockDialog(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> item,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder:
        (_) => StockAdjustmentDialog(
          productName: (item.data()['name'] ?? 'Ürün').toString(),
          adjustStock: (delta, note) async {
            await AppApi.instance.call('adjustStock', {
              'productId': item.id,
              'deltaMilli': delta,
              'note': note,
            });
          },
        ),
  ),
);

Future<void> productDialog(
  BuildContext context, {
  QueryDocumentSnapshot<Map<String, dynamic>>? item,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder:
        (_) => ProductEditorDialog(
          existing: item?.data(),
          existingId: item?.id,
          loadCatalog: ProductCatalog.fetch,
          saveProduct: (values) async {
            final code = (values['barcode'] ?? '').toString().trim();
            if (code.isNotEmpty) {
              final matches =
                  await AppApi.instance
                      .collection('products')
                      .where('barcode', isEqualTo: code)
                      .limit(2)
                      .get();
              if (matches.docs.any((doc) => doc.id != item?.id)) {
                throw const FormatException(
                  'Bu barkod başka bir üründe kayıtlı.',
                );
              }
            }
            if (item == null) {
              await AppApi.instance.create('products', values);
            } else {
              await AppApi.instance.edit('products', item.id, values);
            }
          },
        ),
  ),
);

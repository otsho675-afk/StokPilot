import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';
import 'paywall_page.dart';

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
  int visibleCount = 30;
  final search = TextEditingController();

  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> _addProduct() async {
    try {
      final ws = await AppApi.instance.workspace.get();
      final ent = await AppApi.instance.collection('entitlements').doc('current').get();
      final e = ent.data() ?? {};
      final expiry = e['expiresAt'];
      final pro = e['status'] == 'active' && e['source'] == 'revenuecat' &&
        expiry is Timestamp && expiry.toDate().isAfter(DateTime.now());
      final count = (ws.data()?['productCount'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (!pro && count >= 50) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()));
      } else {
        await productDialog(context);
      }
    } catch (e) {
      if (mounted) notify(context, 'Ürün limiti kontrol edilemedi: $e', error: true);
    }
  }

  bool _matches(Map<String, dynamic> m) {
    final qty = (m['stockMilli'] as num?)?.toInt() ?? 0;
    final min = (m['minStockMilli'] as num?)?.toInt() ?? 0;
    final active = m['isActive'] != false;
    final byStock = switch (stockFilter) {
      'low' => active && qty <= min,
      'empty' => active && qty <= 0,
      'inactive' => !active,
      _ => true,
    };
    return byStock && (categoryFilter.isEmpty || m['categoryId'] == categoryFilter) &&
      [m['name'], m['sku'], m['barcode']].any((field) =>
        (field ?? '').toString().toLowerCase().contains(query));
  }

  int _compare(QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b) {
    final one = a.data(), two = b.data();
    switch (sortBy) {
      case 'stock':
        return ((one['stockMilli'] as num?)?.toInt() ?? 0)
          .compareTo((two['stockMilli'] as num?)?.toInt() ?? 0);
      case 'price':
        return ((two['salePriceMinor'] as num?)?.toInt() ?? 0)
          .compareTo((one['salePriceMinor'] as num?)?.toInt() ?? 0);
      case 'new':
        final d1 = (one['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final d2 = (two['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return d2.compareTo(d1);
      default:
        return (one['name'] ?? '').toString().toLowerCase()
          .compareTo((two['name'] ?? '').toString().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(title: 'Ürünler ve stoklar',
        subtitle: 'Ürünlerini ara, düzenle, kritik seviyeleri takip et.',
        action: FilledButton.icon(onPressed: _addProduct,
          icon: const Icon(Icons.add_rounded), label: const Text('Yeni ürün'))),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.workspace.snapshots(),
        builder: (context, ws) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppApi.instance.entitlement(),
          builder: (context, ent) {
            final e = ent.data?.data() ?? {};
            final expiry = e['expiresAt'];
            final pro = e['status'] == 'active' && e['source'] == 'revenuecat' &&
              expiry is Timestamp && expiry.toDate().isAfter(DateTime.now());
            final count = (ws.data?.data()?['productCount'] as num?)?.toInt() ?? 0;
            return Padding(padding: const EdgeInsets.only(bottom: 16),
              child: DataPanel(child: LayoutBuilder(builder: (context, c) {
                final remaining = (50 - count).clamp(0, 50);
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: softGreen,
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(pro ? Icons.workspace_premium_outlined : Icons.inventory_2_outlined,
                        color: green)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pro ? 'StokPilot Pro • Sınırsız ürün' : '$count / 50 ücretsiz ürün',
                        style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                      if (!pro) Text('$remaining ürün hakkın kaldı',
                        style: const TextStyle(color: muted, fontSize: 12)),
                    ])),
                    if (!pro && c.maxWidth > 380) TextButton.icon(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PaywallPage())),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Pro')), 
                  ]),
                  if (!pro) ...[
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: (count / 50).clamp(0.0, 1.0), minHeight: 7,
                        color: count >= 45 ? amber : green,
                        backgroundColor: const Color(0xFFE5EEED))),
                  ],
                ]);
              })),
            );
          },
        ),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('categories'),
        builder: (context, categories) {
          final cats = categories.data?.docs ?? [];
          final selectedCategory = cats.any((d) => d.id == categoryFilter)
            ? categoryFilter : '';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, c) {
                final searchField = TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  onChanged: (s) => setState(() {
                    query = s.trim().toLowerCase(); visibleCount = 30;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Ürün adı, barkod veya stok kodu',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty ? null : IconButton(
                      tooltip: 'Aramayı temizle',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        search.clear(); query = ''; visibleCount = 30;
                      })),
                  ),
                );
                final category = DropdownButtonFormField<String>(
                  key: ValueKey(selectedCategory),
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [const DropdownMenuItem(value: '', child: Text('Tüm kategoriler')),
                    ...cats.map((d) => DropdownMenuItem(
                      value: d.id, child: Text('${d.data()['name'] ?? ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis)))],
                  onChanged: (s) => setState(() {
                    categoryFilter = s ?? ''; visibleCount = 30;
                  }),
                );
                if (c.maxWidth < 560) return Column(children: [
                  searchField, const SizedBox(height: 10), category,
                ]);
                return Row(children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12), Expanded(flex: 2, child: category),
                ]);
              }),
              const SizedBox(height: 14),
              Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _filter('all', 'Tümü', Icons.apps_rounded),
                  _filter('low', 'Kritik', Icons.warning_amber_rounded),
                  _filter('empty', 'Tükenen', Icons.remove_shopping_cart_outlined),
                  _filter('inactive', 'Pasif', Icons.visibility_off_outlined),
                  PopupMenuButton<String>(tooltip: 'Sıralama',
                    initialValue: sortBy,
                    onSelected: (s) => setState(() { sortBy = s; visibleCount = 30; }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'name', child: Text('Ada göre (A-Z)')),
                      PopupMenuItem(value: 'stock', child: Text('Az stok önce')),
                      PopupMenuItem(value: 'price', child: Text('Yüksek fiyat önce')),
                      PopupMenuItem(value: 'new', child: Text('Yeni eklenen önce')),
                    ],
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.sort_rounded, color: green, size: 19),
                        SizedBox(width: 5), Text('Sırala', style: TextStyle(color: green,
                          fontWeight: FontWeight.w700)),
                      ])),
                  ),
                ]),
            ])),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppApi.instance.watch('products'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return DataPanel(child: Text('Ürünler yüklenemedi: ${snapshot.error}'));
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final filtered = snapshot.data!.docs.where((d) => _matches(d.data()))
                  .toList()..sort(_compare);
                if (filtered.isEmpty) {
                  return DataPanel(child: BlankState(title: 'Ürün bulunamadı',
                    message: query.isEmpty && stockFilter == 'all'
                      ? 'Başlamak için yeni bir ürün ekle.'
                      : 'Arama veya filtrelerini değiştirmeyi dene.',
                    icon: Icons.inventory_2_outlined,
                    action: query.isEmpty && stockFilter == 'all'
                      ? FilledButton.icon(onPressed: _addProduct,
                        icon: const Icon(Icons.add), label: const Text('Ürün ekle'))
                      : TextButton(onPressed: () => setState(() {
                          query = ''; search.clear(); categoryFilter = '';
                          stockFilter = 'all'; visibleCount = 30;
                        }), child: const Text('Filtreleri temizle'))));
                }
                final visible = filtered.take(visibleCount).toList();
                return DataPanel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionHeading(title: 'Ürün listesi',
                      subtitle: '${filtered.length} eşleşen ürün'),
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, c) => Column(children: [
                      ...visible.map((item) => c.maxWidth < 650
                        ? _mobileProduct(context, item)
                        : _wideProduct(context, item)),
                    ])),
                    if (filtered.length > visible.length) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(onPressed: () => setState(() => visibleCount += 30),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text('Daha fazla göster (${filtered.length - visible.length} kaldı)')),
                    ],
                  ]));
              },
            ),
          ]);
        },
      ),
    ],
  );

  Widget _filter(String id, String label, IconData icon) => ChoiceChip(
    selected: stockFilter == id,
    label: Text(label), avatar: Icon(icon, size: 16),
    onSelected: (_) => setState(() { stockFilter = id; visibleCount = 30; }),
  );

  Widget _productActions(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> p) => PopupMenuButton<String>(
    tooltip: 'Ürün işlemleri',
    onSelected: (value) {
      if (value == 'edit') productDialog(context, item: p);
      if (value == 'stock') stockDialog(context, p);
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: '${p.data()['barcode'] ?? ''}'));
        notify(context, 'Barkod kopyalandı.');
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Text('Ürünü düzenle')),
      const PopupMenuItem(value: 'stock', child: Text('Stok giriş / çıkış')),
      if ('${p.data()['barcode'] ?? ''}'.isNotEmpty)
        const PopupMenuItem(value: 'copy', child: Text('Barkodu kopyala')),
    ],
  );

  Widget _mobileProduct(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> p) {
    final m = p.data();
    final qty = (m['stockMilli'] as num?)?.toInt() ?? 0;
    final min = (m['minStockMilli'] as num?)?.toInt() ?? 0;
    final disabled = m['isActive'] == false;
    final alert = qty <= min;
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: alert ? const Color(0xFFFFF0DD) : softGreen,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.inventory_2_outlined, color: alert ? amber : green)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['name'] ?? 'Ürün'}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
              Text('${m['sku'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: muted)),
            ])),
            _productActions(context, p),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            StatusPill(label: 'Stok ${quantity(qty)}', color: alert ? amber : green),
            if (disabled) const StatusPill(label: 'Pasif', color: muted),
            StatusPill(label: 'KDV %${((m['taxRateBps'] ?? 0) / 100).toStringAsFixed(0)}', color: ink),
          ]),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: Text('Satış ${money((m['salePriceMinor'] as num?)?.toInt() ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: ink))),
            TextButton.icon(onPressed: () => stockDialog(context, p),
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Stok işlemi')),
          ]),
        ])),
    );
  }

  Widget _wideProduct(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> p) {
    final m = p.data();
    final qty = (m['stockMilli'] as num?)?.toInt() ?? 0;
    final threshold = (m['minStockMilli'] as num?)?.toInt() ?? 0;
    final alert = qty <= threshold;
    return Column(children: [
      ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        leading: CircleAvatar(backgroundColor: alert ? const Color(0xFFFFF0DD) : softGreen,
          child: Icon(Icons.inventory_2_outlined, color: alert ? amber : green)),
        title: Text('${m['name'] ?? 'Ürün'}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
        subtitle: Text('SKU: ${m['sku'] ?? '—'}   •   ${m['barcode'] ?? ''}\n'
          'Satış ${money((m['salePriceMinor'] as num?)?.toInt() ?? 0)}   •   '
          'KDV %${((m['taxRateBps'] ?? 0) / 100).toStringAsFixed(0)}'),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusPill(label: 'Stok ${quantity(qty)}', color: alert ? amber : green),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Stok giriş / çıkış',
            onPressed: () => stockDialog(context, p),
            icon: const Icon(Icons.tune_rounded, color: green)),
          _productActions(context, p),
        ])),
      const Divider(height: 1, color: line),
    ]);
  }
}

Future<void> stockDialog(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> item) async {
  final value = TextEditingController(), note = TextEditingController(); bool addition = true, busy = false;
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
    title: Text('${item.data()['name']} • Stok düzelt'),
    content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
      SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('Giriş')), ButtonSegment(value: false, label: Text('Çıkış'))], selected: {addition}, onSelectionChanged: (s) => update(() => addition = s.first)),
      const SizedBox(height: 14), TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Miktar (ör: 2,5)')),
      const SizedBox(height: 12), TextField(controller: note, decoration: const InputDecoration(labelText: 'Açıklama')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Kapat')),
      FilledButton(onPressed: busy ? null : () async {
        try {
          final qty = parseQty(value.text); if (qty <= 0) throw const FormatException('Miktar sıfırdan büyük olmalı.');
          update(() => busy = true);
          await AppApi.instance.call('adjustStock', {'productId': item.id, 'deltaMilli': addition ? qty : -qty, 'note': note.text.trim()});
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        } catch (e) { if (context.mounted) notify(context, '$e', error: true); update(() => busy = false); }
      }, child: const Text('Kaydet')),
    ],
  )));
  value.dispose(); note.dispose();
}
Future<void> productDialog(BuildContext context, {QueryDocumentSnapshot<Map<String,dynamic>>? item}) async {
  final existing = item?.data();
  final name = TextEditingController(text: existing?['name'] ?? ''), sku = TextEditingController(text: existing?['sku'] ?? ''),
    barcode = TextEditingController(text: existing?['barcode'] ?? ''), purchase = TextEditingController(text: existing == null ? '0' : (existing['purchasePriceMinor'] / 100).toStringAsFixed(2).replaceAll('.', ',')),
    sale = TextEditingController(text: existing == null ? '0' : (existing['salePriceMinor'] / 100).toStringAsFixed(2).replaceAll('.', ',')),
    minimum = TextEditingController(text: existing == null ? '0' : quantity(existing['minStockMilli'] ?? 0));
  String categoryId = existing?['categoryId'] ?? '', unitId = existing?['unitId'] ?? '', taxId = '';
  bool isActive = existing?['isActive'] ?? true, saving = false;
  final api = AppApi.instance;
  final categoryDocs = (await api.collection('categories').get()).docs;
  final unitDocs = (await api.collection('units').get()).docs;
  final taxDocs = (await api.collection('taxRates').get()).docs;
  if (!context.mounted) return;
  if (categoryId.isNotEmpty && !categoryDocs.any((d) => d.id == categoryId)) categoryId = '';
  if (unitId.isNotEmpty && !unitDocs.any((d) => d.id == unitId)) unitId = '';
  if (existing != null) {
    final matched = taxDocs.where((d) => d.data()['rateBps'] == existing['taxRateBps']);
    if (matched.isNotEmpty) taxId = matched.first.id;
  }
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
    title: Text(item == null ? 'Yeni ürün' : 'Ürün düzenle'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Ürün adı *')),
      const SizedBox(height: 10), ResponsiveFields(first: TextField(controller: sku, decoration: const InputDecoration(labelText: 'Stok kodu (SKU)')), second: TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barkod'))),
      const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: categoryId, isExpanded: true, decoration: const InputDecoration(labelText: 'Kategori'), items: [const DropdownMenuItem(value: '', child: Text('Seçiniz')), ...categoryDocs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? '')))], onChanged: (s) => update(() => categoryId = s ?? '')),
      const SizedBox(height: 10), ResponsiveFields(
        first: DropdownButtonFormField<String>(initialValue: unitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Birim'), items: [const DropdownMenuItem(value: '', child: Text('Seçiniz')), ...unitDocs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? '')))], onChanged: (s) => update(() => unitId = s ?? '')),
        second: DropdownButtonFormField<String>(initialValue: taxId, isExpanded: true, decoration: const InputDecoration(labelText: 'KDV oranı'), items: [const DropdownMenuItem(value: '', child: Text('%0')), ...taxDocs.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.data()['name']}')))], onChanged: (s) => update(() => taxId = s ?? '')),
      ),
      const SizedBox(height: 10), ResponsiveFields(first: TextField(controller: purchase, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Alış fiyatı ₺ (KDV hariç)')), second: TextField(controller: sale, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Satış fiyatı ₺ (KDV hariç)'))),
      const SizedBox(height: 10), TextField(controller: minimum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kritik stok eşiği')),
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Ürün aktif'), value: isActive, onChanged: (v) => update(() => isActive = v)),
      const Text('İlk stok miktarını ürün kaydından sonra “Stok düzelt” ile ekleyin.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
      FilledButton(onPressed: saving ? null : () async {
        try {
          if (name.text.trim().isEmpty) throw const FormatException('Ürün adı zorunlu.');
          final rate = taxDocs.where((d) => d.id == taxId);
          final data = <String, dynamic>{'name': name.text.trim(), 'sku': sku.text.trim(), 'barcode': barcode.text.trim(),
            'categoryId': categoryId, 'unitId': unitId, 'taxRateBps': rate.isNotEmpty ? rate.first.data()['rateBps'] : 0,
            'purchasePriceMinor': parseMoney(purchase.text), 'salePriceMinor': parseMoney(sale.text), 'minStockMilli': parseQty(minimum.text), 'isActive': isActive};
          update(() => saving = true);
          if (item == null) { await api.create('products', data); }
          else { await api.edit('products', item.id, data); }
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        } catch (e) { if (context.mounted) notify(context, e.toString().contains('resource-exhausted') ? '50 ürün sınırına ulaştınız. Pro aboneliği başlatın.' : '$e', error: true); update(() => saving = false); }
      }, child: const Text('Kaydet')),
    ],
  )));
  for (final c in [name, sku, barcode, purchase, sale, minimum]) { c.dispose(); }
}

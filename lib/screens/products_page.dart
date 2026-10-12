import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';
import 'paywall_page.dart';

class ProductsPage extends StatefulWidget { const ProductsPage({super.key}); @override State<ProductsPage> createState() => _ProductsPageState(); }
class _ProductsPageState extends State<ProductsPage> {
  String query = '', categoryFilter = '';
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    PageTitle(title: 'Ürün ve stok yönetimi', subtitle: 'Barkod, kategori, birim, fiyat ve KDV tek yerde.', action: FilledButton.icon(onPressed: () async {
      final ws = await AppApi.instance.workspace.get();
      final ent = await AppApi.instance.collection('entitlements').doc('current').get();
      final e = ent.data() ?? {};
      final expires = e['expiresAt'];
      final pro = e['status'] == 'active' && e['source'] == 'revenuecat' && expires is Timestamp && expires.toDate().isAfter(DateTime.now());
      final count = (ws.data()?['productCount'] as num?)?.toInt() ?? 0;
      if (!context.mounted) return;
      if (!pro && count >= 50) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallPage()));
      } else {
        await productDialog(context);
      }
    }, icon: const Icon(Icons.add), label: const Text('Ürün ekle'))),
    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: AppApi.instance.workspace.snapshots(), builder: (context, wsState) {
      final count = (wsState.data?.data()?['productCount'] as num?)?.toInt() ?? 0;
      return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream: AppApi.instance.entitlement(), builder: (context, entState) {
        final e = entState.data?.data() ?? {};
        final exp = e['expiresAt'];
        final pro = e['status'] == 'active' && e['source'] == 'revenuecat' && exp is Timestamp && exp.toDate().isAfter(DateTime.now());
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: DataPanel(child: Row(children: [
          Icon(pro ? Icons.workspace_premium_outlined : Icons.inventory_outlined, color: green), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pro ? 'Pro • Sınırsız ürün' : 'Ücretsiz plan • $count/50 ürün', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (!pro) LinearProgressIndicator(value: (count / 50).clamp(0.0, 1.0), minHeight: 5),
          ])),
          if (!pro) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage())), child: const Text('Pro’ya geç')),
        ]))));
      });
    }),
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: AppApi.instance.watch('categories'), builder: (context, catSnap) {
      final cats = catSnap.data?.docs ?? [];
      return Column(children: [
        Row(children: [
          Expanded(child: TextField(onChanged: (s) => setState(() => query = s.toLowerCase().trim()), decoration: const InputDecoration(hintText: 'Ürün adı, stok kodu veya barkod ara', prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white))),
          const SizedBox(width: 10),
          SizedBox(width: 135, child: DropdownButtonFormField<String>(initialValue: categoryFilter, isExpanded: true, decoration: const InputDecoration(labelText: 'Kategori', filled: true, fillColor: Colors.white), items: [const DropdownMenuItem(value: '', child: Text('Tümü')), ...cats.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? '')))], onChanged: (s) => setState(() => categoryFilter = s ?? ''))),
        ]),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: AppApi.instance.watch('products'), builder: (context, state) {
          if (state.hasError) return Text('${state.error}');
          if (!state.hasData) return const LinearProgressIndicator();
          final items = state.data!.docs.where((d) {
            final m = d.data();
            return (categoryFilter.isEmpty || m['categoryId'] == categoryFilter) &&
              [m['name'], m['sku'], m['barcode']].any((s) => (s ?? '').toString().toLowerCase().contains(query));
          }).toList()..sort((a,b) => (a.data()['name'] ?? '').toString().compareTo((b.data()['name'] ?? '').toString()));
          if (items.isEmpty) return const DataPanel(child: BlankState(message: 'Bu filtreye uygun ürün yok. İlk ürününüzü ekleyin.', icon: Icons.inventory_2_outlined));
          return DataPanel(child: Column(children: items.map((p) {
            final m = p.data(); final stock = (m['stockMilli'] ?? 0) as int, min = (m['minStockMilli'] ?? 0) as int;
            return Column(children: [
              ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                leading: CircleAvatar(backgroundColor: stock <= min ? const Color(0xFFFFEADB) : const Color(0xFFE3F4ED), child: Icon(Icons.inventory_2_outlined, color: stock <= min ? const Color(0xFFBF6619) : green)),
                title: Text(m['name'] ?? 'Ürün', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${m['sku'] ?? ''}  •  Stok ${quantity(stock)}  •  Satış ${money(m['salePriceMinor'] ?? 0)}  •  KDV %${((m['taxRateBps'] ?? 0) / 100).toStringAsFixed(0)}'),
                trailing: PopupMenuButton<String>(tooltip: 'Ürün işlemleri', onSelected: (value) { if (value == 'edit') productDialog(context, item: p); if (value == 'stock') stockDialog(context, p); }, itemBuilder: (c) => const [
                  PopupMenuItem(value: 'edit', child: Text('Düzenle')), PopupMenuItem(value: 'stock', child: Text('Stok düzelt')),
                ]),
              ),
              const Divider(height: 1),
            ]);
          }).toList()));
        }),
      ]);
    }),
  ]);
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
      const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: sku, decoration: const InputDecoration(labelText: 'Stok kodu (SKU)'))), const SizedBox(width: 10), Expanded(child: TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barkod')))]),
      const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: categoryId, isExpanded: true, decoration: const InputDecoration(labelText: 'Kategori'), items: [const DropdownMenuItem(value: '', child: Text('Seçiniz')), ...categoryDocs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? '')))], onChanged: (s) => update(() => categoryId = s ?? '')),
      const SizedBox(height: 10), Row(children: [
        Expanded(child: DropdownButtonFormField<String>(initialValue: unitId, isExpanded: true, decoration: const InputDecoration(labelText: 'Birim'), items: [const DropdownMenuItem(value: '', child: Text('Seçiniz')), ...unitDocs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? '')))], onChanged: (s) => update(() => unitId = s ?? ''))),
        const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<String>(initialValue: taxId, isExpanded: true, decoration: const InputDecoration(labelText: 'KDV oranı'), items: [const DropdownMenuItem(value: '', child: Text('%0')), ...taxDocs.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.data()['name']}')))], onChanged: (s) => update(() => taxId = s ?? ''))),
      ]),
      const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: purchase, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Alış fiyatı ₺ (KDV hariç)'))), const SizedBox(width: 10), Expanded(child: TextField(controller: sale, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Satış fiyatı ₺ (KDV hariç)')))]),
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

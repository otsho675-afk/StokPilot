import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class _Line {
  _Line(this.id, this.name, this.qtyMilli, this.priceMinor, this.taxBps);
  String id, name;
  int qtyMilli, priceMinor, taxBps;
  int get net => (qtyMilli * priceMinor / 1000).round();
  int get tax => (net * taxBps / 10000).round();
  int get total => net + tax;
  Map<String,dynamic> get json => {'productId': id, 'quantityMilli': qtyMilli, 'priceMinor': priceMinor, 'taxBps': taxBps};
}
class TradesPage extends StatefulWidget {
  const TradesPage({super.key, required this.type});
  final String type;
  @override State<TradesPage> createState() => _TradesPageState();
}
class _TradesPageState extends State<TradesPage> {
  final lines = <_Line>[];
  final paid = TextEditingController(), note = TextEditingController();
  String contactId = '';
  bool busy = false;
  bool get sale => widget.type == 'sale';
  int get total => lines.fold(0, (s, line) => s + line.total);
  @override void dispose() { paid.dispose(); note.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    PageTitle(title: sale ? 'Hızlı satış' : 'Tedarikçi alışı', subtitle: sale ? 'Ürün seç, miktarı belirle ve stoğu otomatik güncelle.' : 'Alış kaydını gir, stoklarını anında artır.'),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: AppApi.instance.watch('products'), builder: (context, productSnap) {
      if (!productSnap.hasData) return const LinearProgressIndicator();
      final products = productSnap.data!.docs.where((d) => d.data()['isActive'] != false).toList();
      return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: AppApi.instance.watch('contacts'), builder: (context, contactSnap) {
        final contacts = contactSnap.data?.docs.where((d) => d.data()['type'] == 'both' || d.data()['type'] == (sale ? 'customer' : 'supplier')).toList() ?? [];
        return DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(title: sale ? 'Yeni satış' : 'Yeni alış', subtitle: 'Adım 1: cari seç • Adım 2: ürün ekle • Adım 3: işlemi onayla'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(key: ValueKey('${widget.type}-$contactId'), initialValue: contactId, isExpanded: true, decoration: InputDecoration(labelText: sale ? 'Müşteri / Cari' : 'Tedarikçi / Cari'),
            items: [const DropdownMenuItem(value: '', child: Text('Peşin • cari olmadan')), ...contacts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? '')))],
            onChanged: (s) => setState(() => contactId = s ?? '')),
          const SizedBox(height: 14),
          Autocomplete<QueryDocumentSnapshot<Map<String,dynamic>>>(
            displayStringForOption: (p) => p.data()['name'] ?? '',
            optionsBuilder: (value) => products.where((p) => !lines.any((l) => l.id == p.id) && [p.data()['name'], p.data()['sku'], p.data()['barcode']].any((s) => (s ?? '').toString().toLowerCase().contains(value.text.toLowerCase()))).take(15),
            onSelected: (p) async { final line = await _addLineDialog(context, p, sale); if (mounted && line != null) setState(() => lines.add(line)); },
            fieldViewBuilder: (ctx, controller, focus, onSubmit) => TextField(controller: controller, focusNode: focus, decoration: const InputDecoration(labelText: 'Ürün seç • ad / barkod / stok kodu', prefixIcon: Icon(Icons.add_circle_outline), suffixIcon: Icon(Icons.search))),
          ),
          const SizedBox(height: 14),
          if (lines.isEmpty) const BlankState(title: 'Sepet henüz boş', message: 'Ürün adı veya barkod ile arayıp ilk kalemi ekle.', icon: Icons.shopping_basket_outlined),
          ...lines.map((line) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                    Text('${quantity(line.qtyMilli)} × ${money(line.priceMinor)} • KDV %${line.taxBps / 100}',
                      style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(money(line.total),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: green)),
                  ])),
                IconButton(tooltip: 'Ürünü çıkar',
                  onPressed: () => setState(() => lines.remove(line)),
                  icon: const Icon(Icons.close_rounded, size: 20)),
              ])),
          )),
          const Divider(),
          _totalRow('Matrah', money(lines.fold(0, (s,l) => s + l.net))),
          const SizedBox(height: 5), _totalRow('KDV', money(lines.fold(0, (s,l) => s + l.tax))),
          const SizedBox(height: 8), _totalRow('Genel toplam', money(total), highlight: true),
          const SizedBox(height: 16),
          if (contactId.isNotEmpty) TextField(controller: paid, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: sale ? 'Alınan tahsilat (₺)' : 'Yapılan ödeme (₺)', helperText: 'Boş bırakırsanız bakiye veresiye/cariye işlenir.')),
          const SizedBox(height: 10), TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'İşlem notu (opsiyonel)')),
          const SizedBox(height: 15), SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.check_circle_outline), label: Text(busy ? 'Kaydediliyor...' : (sale ? 'Satışı tamamla' : 'Alışı tamamla')), onPressed: busy || lines.isEmpty ? null : save)),
        ]));
      });
    }),
    const SizedBox(height: 22),
    Text(sale ? 'Son satışlar' : 'Son alışlar', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: AppApi.instance.watch('trades'), builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator();
      final docs = snap.data!.docs.where((d) => d.data()['type'] == widget.type).toList()..sort((a,b) => (((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch) ?? 0).compareTo(((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch) ?? 0));
      if (docs.isEmpty) return const DataPanel(child: BlankState(message: 'Henüz işlem yapılmadı.', icon: Icons.receipt_long_outlined));
      return DataPanel(child: Column(children: docs.take(30).map((d) {
        final m = d.data();
        return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long_outlined, color: green),
          title: Text('${sale ? 'Satış' : 'Alış'} • ${money(m['totalMinor'] ?? 0)}'), subtitle: Text('${dateOf(m['createdAt'])} • ${(m['lines'] as List?)?.length ?? 0} kalem'),
          trailing: const Icon(Icons.chevron_right), onTap: () => showTradeDetails(context, m));
      }).toList()));
    }),
  ]);
  Widget _totalRow(String title, String value, {bool highlight = false}) =>
    Row(children: [
      Expanded(child: Text(title, style: TextStyle(color: ink,
        fontSize: highlight ? 16 : 14,
        fontWeight: highlight ? FontWeight.w800 : FontWeight.w500))),
      Flexible(child: FittedBox(fit: BoxFit.scaleDown,
        child: Text(value, style: TextStyle(
          fontSize: highlight ? 22 : 15,
          fontWeight: FontWeight.w900,
          color: highlight ? green : ink)))),
    ]);

  Future<void> save() async {
    if (busy || lines.isEmpty) return;
    try {
      final payment = contactId.isEmpty ? total : (paid.text.trim().isEmpty ? 0 : parseMoney(paid.text));
      if (payment > total) throw const FormatException('Tahsilat / ödeme toplamdan fazla olamaz.');
      if (!await confirm(context, sale ? 'Satışı onayla' : 'Alışı onayla', '${lines.length} kalem, toplam ${money(total)}. İşlem stok ve cari hesaplara işlenecek.')) return;
      setState(() => busy = true);
      await AppApi.instance.call('commitTrade', {'type': widget.type, 'contactId': contactId.isEmpty ? null : contactId, 'lines': lines.map((l) => l.json).toList(), 'paidMinor': payment, 'note': note.text.trim()});
      if (!mounted) return;
      setState(() { lines.clear(); paid.clear(); note.clear(); contactId = ''; });
      notify(context, sale ? 'Satış kaydedildi.' : 'Alış kaydedildi.');
    } catch (e) { if (mounted) notify(context, '$e', error: true); }
    finally { if (mounted) setState(() => busy = false); }
  }
}
Future<_Line?> _addLineDialog(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> product, bool sale) async {
  final m = product.data();
  final qty = TextEditingController(text: '1');
  final price = TextEditingController(text: (((sale ? m['salePriceMinor'] : m['purchasePriceMinor']) ?? 0) / 100).toStringAsFixed(2).replaceAll('.', ','));
  _Line? result;
  await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(m['name'] ?? 'Ürün'),
    content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mevcut stok: ${quantity(m['stockMilli'] ?? 0)}', style: const TextStyle(color: Colors.blueGrey)),
      const SizedBox(height: 14), TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Miktar')),
      const SizedBox(height: 12), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'KDV hariç birim fiyat (₺)')),
      const SizedBox(height: 8), Text('KDV: %${(m['taxRateBps'] ?? 0) / 100}'),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
      FilledButton(onPressed: () {
        try {
          final q = parseQty(qty.text); if (q <= 0) throw const FormatException('Miktar sıfırdan büyük olmalı.');
          if (sale && q > (m['stockMilli'] ?? 0)) throw const FormatException('Yetersiz stok.');
          result = _Line(product.id, m['name'] ?? '', q, parseMoney(price.text), (m['taxRateBps'] ?? 0) as int);
          Navigator.pop(dialogContext);
        } catch (e) { notify(context, '$e', error: true); }
      }, child: const Text('Ekle')),
    ],
  ));
  qty.dispose(); price.dispose(); return result;
}
void showTradeDetails(BuildContext context, Map<String,dynamic> trade) {
  showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: Text('${trade['type'] == 'sale' ? 'Satış' : 'Alış'} detayı'),
    content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(dateOf(trade['createdAt'])), const SizedBox(height: 12),
      ...((trade['lines'] as List?) ?? []).map((raw) { final l = Map<String,dynamic>.from(raw as Map); return ListTile(contentPadding: EdgeInsets.zero, title: Text(l['name'] ?? ''), subtitle: Text('${quantity(l['quantityMilli'] ?? 0)} × ${money(l['priceMinor'] ?? 0)} + KDV %${(l['taxBps'] ?? 0) / 100}'), trailing: Text(money(l['totalMinor'] ?? 0))); }),
      const Divider(), Text('Ara toplam: ${money(trade['netMinor'] ?? 0)}'), Text('KDV: ${money(trade['taxMinor'] ?? 0)}'),
      Text('TOPLAM: ${money(trade['totalMinor'] ?? 0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text('Ödenen: ${money(trade['paidMinor'] ?? 0)}'),
      if ((trade['note'] ?? '').toString().isNotEmpty) Text('Not: ${trade['note']}'),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
  ));
}

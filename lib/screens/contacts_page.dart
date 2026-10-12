import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class ContactsPage extends StatefulWidget { const ContactsPage({super.key}); @override State<ContactsPage> createState() => _ContactsPageState(); }
class _ContactsPageState extends State<ContactsPage> {
  String search = '', filter = 'all';
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    PageTitle(title: 'Cari hesaplar', subtitle: 'Müşterileri, tedarikçileri ve borç-alacak takibini yönetin.', action: FilledButton.icon(onPressed: () => contactDialog(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('Cari ekle'))),
    TextField(onChanged: (s) => setState(() => search = s.toLowerCase()), decoration: const InputDecoration(labelText: 'Cari adı, telefon veya vergi numarası ara', prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white)),
    const SizedBox(height: 12), Wrap(spacing: 8, children: [
      ChoiceChip(label: const Text('Tümü'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
      ChoiceChip(label: const Text('Müşteriler'), selected: filter == 'customer', onSelected: (_) => setState(() => filter = 'customer')),
      ChoiceChip(label: const Text('Tedarikçiler'), selected: filter == 'supplier', onSelected: (_) => setState(() => filter = 'supplier')),
    ]), const SizedBox(height: 12),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: AppApi.instance.watch('contacts'), builder: (context, snap) {
      if (snap.hasError) return Text('${snap.error}');
      if (!snap.hasData) return const LinearProgressIndicator();
      final entries = snap.data!.docs.where((d) {
        final m = d.data();
        return (filter == 'all' || m['type'] == 'both' || m['type'] == filter) &&
          [m['name'], m['phone'], m['taxNumber']].any((s) => (s ?? '').toString().toLowerCase().contains(search));
      }).toList()..sort((a,b) => (a.data()['name'] ?? '').toString().compareTo((b.data()['name'] ?? '').toString()));
      if (entries.isEmpty) return const DataPanel(child: BlankState(message: 'Henüz cari kaydı bulunmuyor.', icon: Icons.people_outline));
      return DataPanel(child: Column(children: entries.map((d) {
        final m = d.data(); final balance = (m['balanceMinor'] ?? 0) as int;
        final type = switch (m['type']) { 'customer' => 'Müşteri', 'supplier' => 'Tedarikçi', _ => 'Müşteri / Tedarikçi' };
        return Column(children: [ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(backgroundColor: const Color(0xFFE9F3F5), child: Icon(m['type'] == 'supplier' ? Icons.local_shipping_outlined : Icons.person_outline, color: ink)),
          title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('$type  •  ${m['phone'] ?? ''}\n${balance > 0 ? 'Alacak' : balance < 0 ? 'Borç' : 'Bakiye'}: ${money(balance.abs())}'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (action) { if (action == 'edit') contactDialog(context, item: d); if (action == 'payment') paymentDialog(context, d); if (action == 'history') contactHistory(context, d); }, itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'edit', child: Text('Düzenle')), PopupMenuItem(value: 'payment', child: Text('Tahsilat / ödeme')), PopupMenuItem(value: 'history', child: Text('Hesap hareketleri')),
          ]),
        ), const Divider(height: 1)]);
      }).toList()));
    }),
  ]);
}
Future<void> contactDialog(BuildContext context, {QueryDocumentSnapshot<Map<String,dynamic>>? item}) async {
  final m = item?.data();
  final name = TextEditingController(text: m?['name'] ?? ''), phone = TextEditingController(text: m?['phone'] ?? ''),
    email = TextEditingController(text: m?['email'] ?? ''), tax = TextEditingController(text: m?['taxNumber'] ?? ''),
    address = TextEditingController(text: m?['address'] ?? '');
  String type = m?['type'] ?? 'customer'; bool busy = false;
  await showDialog<void>(context: context, builder: (dc) => StatefulBuilder(builder: (context, update) => AlertDialog(
    title: Text(item == null ? 'Cari ekle' : 'Cari düzenle'),
    content: SizedBox(width: 470, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad / firma ünvanı *')),
      const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Cari türü'), items: const [
        DropdownMenuItem(value: 'customer', child: Text('Müşteri')), DropdownMenuItem(value: 'supplier', child: Text('Tedarikçi')), DropdownMenuItem(value: 'both', child: Text('Her ikisi')),
      ], onChanged: (s) => update(() => type = s ?? type)),
      const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
      const SizedBox(height: 10), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta')),
      const SizedBox(height: 10), TextField(controller: tax, decoration: const InputDecoration(labelText: 'Vergi / T.C. numarası')),
      const SizedBox(height: 10), TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Adres')),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('İptal')),
      FilledButton(onPressed: busy ? null : () async {
        try {
          if (name.text.trim().isEmpty) throw const FormatException('Firma adı zorunlu.');
          update(() => busy = true);
          final data = {'name': name.text.trim(), 'type': type, 'phone': phone.text.trim(), 'email': email.text.trim(), 'taxNumber': tax.text.trim(), 'address': address.text.trim()};
          if (item == null) { await AppApi.instance.create('contacts', {...data, 'balanceMinor': 0}); }
          else { await AppApi.instance.edit('contacts', item.id, data); }
          if (dc.mounted) Navigator.pop(dc);
        } catch (e) { if (context.mounted) notify(context, '$e', error: true); update(() => busy = false); }
      }, child: const Text('Kaydet')),
    ],
  )));
  for (final c in [name, phone, email, tax, address]) { c.dispose(); }
}
Future<void> paymentDialog(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> contact) async {
  final input = TextEditingController(); String type = 'collection'; bool busy = false;
  await showDialog<void>(context: context, builder: (dc) => StatefulBuilder(builder: (context, update) => AlertDialog(
    title: Text('${contact.data()['name']} • Cari hareket'),
    content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'İşlem'), items: const [
        DropdownMenuItem(value: 'collection', child: Text('Tahsilat al (alacağı düşür)')),
        DropdownMenuItem(value: 'payout', child: Text('Ödeme yap (borcu düşür)')),
      ], onChanged: (s) => update(() => type = s ?? type)),
      const SizedBox(height: 12), TextField(controller: input, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tutar (₺)')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('İptal')),
      FilledButton(onPressed: busy ? null : () async {
        try {
          final amount = parseMoney(input.text); if (amount <= 0) throw const FormatException('Sıfırdan büyük tutar girin.');
          update(() => busy = true);
          await AppApi.instance.call('postPayment', {'contactId': contact.id, 'type': type, 'amountMinor': amount});
          if (dc.mounted) Navigator.pop(dc);
        } catch (e) { if (context.mounted) notify(context, '$e', error: true); update(() => busy = false); }
      }, child: const Text('İşlemi kaydet')),
    ],
  )));
  input.dispose();
}
Future<void> contactHistory(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> contact) async {
  final api = AppApi.instance;
  final trades = await api.collection('trades').where('contactId', isEqualTo: contact.id).get();
  final payments = await api.collection('payments').where('contactId', isEqualTo: contact.id).get();
  if (!context.mounted) return;
  final items = <Map<String, dynamic>>[
    ...trades.docs.map((d) => {...d.data(), 'kind': 'trade'}),
    ...payments.docs.map((d) => {...d.data(), 'kind': 'payment'}),
  ]..sort((a,b) => ((b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
  await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: Text('${contact.data()['name']} • Hareketler'),
    content: SizedBox(width: 580, height: 450, child: items.isEmpty ? const BlankState(message: 'Henüz cari hareket yok.', icon: Icons.receipt_long) : ListView.builder(itemCount: items.length, itemBuilder: (c, i) {
      final m = items[i], trade = m['kind'] == 'trade';
      return ListTile(title: Text(trade ? (m['type'] == 'sale' ? 'Satış' : 'Alış') : (m['type'] == 'collection' ? 'Tahsilat' : 'Ödeme')),
        subtitle: Text(dateOf(m['createdAt'])), trailing: Text(money(trade ? m['totalMinor'] : m['amountMinor']), style: const TextStyle(fontWeight: FontWeight.bold)));
    })), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
  ));
}

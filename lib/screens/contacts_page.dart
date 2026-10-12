import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String search = '', filter = 'all';
  int visibleCount = 30;
  final searchController = TextEditingController();
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageTitle(title: 'Müşteriler ve tedarikçiler',
        subtitle: 'Cari hesapları, borç-alacak ve tahsilatları tek yerden yönet.',
        action: FilledButton.icon(onPressed: () => contactDialog(context),
          icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Yeni cari'))),
      DataPanel(child: Column(children: [
        TextField(controller: searchController,
          onChanged: (s) => setState(() {
            search = s.trim().toLowerCase(); visibleCount = 30;
          }),
          decoration: InputDecoration(
            hintText: 'Ad, telefon veya vergi numarası ara',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: search.isEmpty ? null : IconButton(
              tooltip: 'Temizle', icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                searchController.clear(); search = ''; visibleCount = 30;
              })),
          )),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            _filterChip('all', 'Tümü'),
            _filterChip('customer', 'Müşteriler'),
            _filterChip('supplier', 'Tedarikçiler'),
          ])),
      ])),
      const SizedBox(height: 16),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('contacts'), builder: (context, snap) {
          if (snap.hasError) return DataPanel(child: Text('Cariler yüklenemedi: ${snap.error}'));
          if (!snap.hasData) return const LinearProgressIndicator();
          final all = snap.data!.docs;
          final entries = all.where((d) {
            final m = d.data();
            return (filter == 'all' || m['type'] == 'both' || m['type'] == filter) &&
              [m['name'], m['phone'], m['taxNumber']].any((value) =>
                (value ?? '').toString().toLowerCase().contains(search));
          }).toList()..sort((a, b) =>
            (a.data()['name'] ?? '').toString().toLowerCase()
              .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));
          int receivable = 0, payable = 0;
          for (final item in all) {
            final v = (item.data()['balanceMinor'] as num?)?.toInt() ?? 0;
            if (v > 0) receivable += v;
            if (v < 0) payable -= v;
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth < 540 ? 1 : 3;
              final width = (c.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: width, child: MetricCard(title: 'Toplam cari',
                  value: '${all.length}', icon: Icons.people_outline)),
                SizedBox(width: width, child: MetricCard(title: 'Toplam alacak',
                  value: money(receivable), icon: Icons.call_received_rounded)),
                SizedBox(width: width, child: MetricCard(title: 'Toplam borç',
                  value: money(payable), icon: Icons.call_made_rounded)),
              ]);
            }),
            const SizedBox(height: 18),
            DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHeading(title: 'Cari listesi',
                subtitle: '${entries.length} kayıt gösteriliyor'),
              const SizedBox(height: 12),
              if (entries.isEmpty) BlankState(
                title: 'Cari bulunamadı',
                message: search.isNotEmpty || filter != 'all'
                  ? 'Filtreleri değiştirmeyi dene.'
                  : 'İlk müşterini veya tedarikçini ekle.',
                icon: Icons.people_outline,
                action: search.isEmpty && filter == 'all'
                  ? FilledButton.icon(onPressed: () => contactDialog(context),
                    icon: const Icon(Icons.person_add), label: const Text('Cari ekle'))
                  : TextButton(onPressed: () => setState(() {
                    searchController.clear(); search = ''; filter = 'all';
                  }), child: const Text('Filtreyi temizle'))),
              LayoutBuilder(builder: (context, c) => Column(children: [
                ...entries.take(visibleCount).map((d) => _contactEntry(context, d,
                  compact: c.maxWidth < 620)),
              ])),
              if (entries.length > visibleCount) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() => visibleCount += 30),
                  icon: const Icon(Icons.expand_more),
                  label: Text('Daha fazla göster (${entries.length - visibleCount} kaldı)')),
              ],
            ])),
          ]);
        },
      ),
    ],
  );

  Widget _filterChip(String value, String label) => ChoiceChip(
    label: Text(label), selected: filter == value,
    onSelected: (_) => setState(() { filter = value; visibleCount = 30; }),
  );

  Widget _actions(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> item) => PopupMenuButton<String>(
    tooltip: 'Cari işlemleri', onSelected: (action) {
      if (action == 'edit') contactDialog(context, item: item);
      if (action == 'payment') paymentDialog(context, item);
      if (action == 'history') contactHistory(context, item);
    }, itemBuilder: (_) => const [
      PopupMenuItem(value: 'payment', child: Text('Tahsilat / ödeme')),
      PopupMenuItem(value: 'history', child: Text('Hesap hareketleri')),
      PopupMenuItem(value: 'edit', child: Text('Cari düzenle')),
    ]);

  Widget _contactEntry(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> item,
      {required bool compact}) {
    final m = item.data();
    final balance = (m['balanceMinor'] as num?)?.toInt() ?? 0;
    final name = '${m['name'] ?? 'Cari'}';
    final kind = switch (m['type']) {
      'customer' => 'Müşteri', 'supplier' => 'Tedarikçi', _ => 'Müşteri / Tedarikçi',
    };
    final status = balance > 0 ? 'Alacak' : balance < 0 ? 'Borç' : 'Dengede';
    final color = balance > 0 ? green : balance < 0 ? amber : muted;
    if (compact) {
      return Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Container(padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(backgroundColor: softGreen,
                child: Icon(m['type'] == 'supplier'
                  ? Icons.local_shipping_outlined : Icons.person_outline,
                  color: green)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                  Text('$kind  •  ${m['phone'] ?? ''}', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: muted))])),
              _actions(context, item),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusPill(label: '$status: ${money(balance.abs())}', color: color),
                TextButton.icon(onPressed: () => paymentDialog(context, item),
                  icon: const Icon(Icons.payments_outlined, size: 17),
                  label: const Text('Ödeme işlemi')),
              ]),
          ])),
      );
    }
    return Column(children: [
      ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 6),
        leading: CircleAvatar(backgroundColor: softGreen,
          child: Icon(m['type'] == 'supplier' ? Icons.local_shipping_outlined
            : Icons.person_outline, color: green)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800,
          color: ink)),
        subtitle: Text('$kind   •   ${m['phone'] ?? ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusPill(label: '$status ${money(balance.abs())}', color: color),
          const SizedBox(width: 7),
          IconButton(onPressed: () => paymentDialog(context, item),
            tooltip: 'Tahsilat / ödeme',
            icon: const Icon(Icons.payments_outlined, color: green)),
          _actions(context, item),
        ])),
      const Divider(height: 1, color: line),
    ]);
  }
}

Future<void> contactDialog(BuildContext context, {QueryDocumentSnapshot<Map<String,dynamic>>? item}) async {
  final m = item?.data();
  final name = TextEditingController(text: m?['name'] ?? ''), phone = TextEditingController(text: m?['phone'] ?? ''),
    email = TextEditingController(text: m?['email'] ?? ''), tax = TextEditingController(text: m?['taxNumber'] ?? ''),
    address = TextEditingController(text: m?['address'] ?? '');
  String type = m?['type'] ?? 'customer'; bool busy = false;
  await showOwnedDialog<void>(context: context, controllers: [name, phone, email, tax, address], builder: (dc) => StatefulBuilder(builder: (context, update) => ResponsiveFormDialog(
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
}
Future<void> paymentDialog(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> contact) async {
  final input = TextEditingController(); String type = 'collection'; bool busy = false;
  await showOwnedDialog<void>(context: context, controllers: [input], builder: (dc) => StatefulBuilder(builder: (context, update) => ResponsiveFormDialog(
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

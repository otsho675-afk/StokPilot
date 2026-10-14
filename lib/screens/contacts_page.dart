import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.kind});
  final String kind;
  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String search = '';
  int currentPage = 0;
  int pageSize = 10;
  String balanceFilter = 'all', typeFilter = 'all';
  DateTime? dateFrom, dateTo;
  Future<void> chooseDate(bool start) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? dateFrom : dateTo) ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1),
    );
    if (picked != null && mounted) setState(() {
      if (start) { dateFrom = picked; } else { dateTo = picked; }
      currentPage = 0;
    });
  }
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageTitle(
        title: widget.kind == 'supplier' ? 'Tedarikçiler' : 'Müşteri carileri',
        subtitle:
            widget.kind == 'supplier'
                ? 'Firma kartları, geriye dönük borçlar, alışlar ve ödemeler.'
                : 'Müşteri kartları, satışlar, alacaklar ve tahsilatlar.',
        action: FilledButton.icon(
          onPressed: () => contactDialog(context, defaultType: widget.kind),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(
            widget.kind == 'supplier' ? 'Yeni tedarikçi' : 'Yeni müşteri',
          ),
        ),
      ),
      DataPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: searchController,
              onChanged:
                  (s) => setState(() {
                    search = s.trim().toLowerCase();
                    currentPage = 0;
                  }),
              decoration: InputDecoration(
                hintText: 'Ad, telefon veya vergi numarası ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    search.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Temizle',
                          icon: const Icon(Icons.close),
                          onPressed:
                              () => setState(() {
                                searchController.clear();
                                search = '';
                                currentPage = 0;
                              }),
                        ),
              ),
            ),
            const SizedBox(height: 10),
            ResponsiveFields(
              first: DropdownButtonFormField<String>(
                initialValue: typeFilter,
                decoration: const InputDecoration(labelText: 'Cari türü', prefixIcon: Icon(Icons.groups_outlined)),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Tüm cariler')),
                  DropdownMenuItem(value: widget.kind, child: Text(widget.kind == 'supplier' ? 'Sadece tedarikçiler' : 'Sadece müşteriler')),
                  const DropdownMenuItem(value: 'both', child: Text('Müşteri / tedarikçi')),
                ],
                onChanged: (v) => setState(() { typeFilter = v ?? 'all'; currentPage = 0; }),
              ),
              second: DropdownButtonFormField<String>(
                initialValue: balanceFilter,
                decoration: const InputDecoration(labelText: 'Bakiye', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tüm bakiyeler')),
                  DropdownMenuItem(value: 'positive', child: Text('Alacaklı')),
                  DropdownMenuItem(value: 'negative', child: Text('Borçlu')),
                  DropdownMenuItem(value: 'zero', child: Text('Dengede')),
                ],
                onChanged: (v) => setState(() { balanceFilter = v ?? 'all'; currentPage = 0; }),
              ),
            ),
            const SizedBox(height: 10),
            ResponsiveFields(
              first: CompactDateField(
                label: 'Başlangıç tarihi', date: dateFrom,
                onTap: () => chooseDate(true),
                onClear: () => setState(() { dateFrom = null; currentPage = 0; }),
              ),
              second: CompactDateField(
                label: 'Bitiş tarihi', date: dateTo,
                onTap: () => chooseDate(false),
                onClear: () => setState(() { dateTo = null; currentPage = 0; }),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('contacts'),
        builder: (context, snap) {
          if (snap.hasError) {
            return DataPanel(child: Text('Cariler yüklenemedi: ${snap.error}'));
          }
          if (!snap.hasData) return const LinearProgressIndicator();
          final all = snap.data!.docs;
          final entries =
              all.where((d) {
                  final m = d.data();
                  final balance = (m['balanceMinor'] as num?)?.toInt() ?? 0;
                  final created = m['createdAt'];
                  final date = created is Timestamp ? created.toDate() : null;
                  final balanceOk = switch (balanceFilter) {
                    'positive' => balance > 0,
                    'negative' => balance < 0,
                    'zero' => balance == 0,
                    _ => true,
                  };
                  final dateOk = (dateFrom == null || (date != null && !date.isBefore(DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day)))) &&
                    (dateTo == null || (date != null && date.isBefore(DateTime(dateTo!.year, dateTo!.month, dateTo!.day + 1))));
                  return (m['type'] == 'both' || m['type'] == widget.kind) &&
                      (typeFilter == 'all' || m['type'] == typeFilter) && balanceOk && dateOk &&
                      [m['name'], m['phone'], m['taxNumber']].any(
                        (value) => (value ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(search),
                      );
                }).toList()
                ..sort(
                  (a, b) => (a.data()['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .compareTo(
                        (b.data()['name'] ?? '').toString().toLowerCase(),
                      ),
                );
          int receivable = 0, payable = 0;
          for (final item in entries) {
            final v = (item.data()['balanceMinor'] as num?)?.toInt() ?? 0;
            if (v > 0) receivable += v;
            if (v < 0) payable -= v;
          }
          final pages = (entries.length + pageSize - 1) ~/ pageSize;
          final page = currentPage.clamp(0, pages == 0 ? 0 : pages - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth < 540 ? 1 : 3;
                  final width = (c.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          title:
                              widget.kind == 'supplier'
                                  ? 'Tedarikçi'
                                  : 'Müşteri',
                          value: '${entries.length}',
                          icon: Icons.people_outline,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          title: 'Alacak',
                          value: money(receivable),
                          icon: Icons.call_received_rounded,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          title: 'Borç',
                          value: money(payable),
                          icon: Icons.call_made_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              DataPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(
                      title:
                          widget.kind == 'supplier'
                              ? 'Tedarikçi listesi'
                              : 'Müşteri listesi',
                      subtitle: '${entries.length} kayıt gösteriliyor',
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      BlankState(
                        title: 'Cari bulunamadı',
                        message:
                            search.isNotEmpty
                                ? 'Aramayı değiştirmeyi dene.'
                                : 'İlk firma kartını ekle.',
                        icon: Icons.people_outline,
                        action:
                            search.isEmpty
                                ? FilledButton.icon(
                                  onPressed:
                                      () => contactDialog(
                                        context,
                                        defaultType: widget.kind,
                                      ),
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Cari ekle'),
                                )
                                : TextButton(
                                  onPressed:
                                      () => setState(() {
                                        searchController.clear();
                                        search = '';
                                      }),
                                  child: const Text('Filtreyi temizle'),
                                ),
                      ),
                    LayoutBuilder(
                      builder:
                          (context, c) => Column(
                            children: [
                              ...entries
                                  .skip(page * pageSize)
                                  .take(pageSize)
                                  .map(
                                    (d) => _contactEntry(
                                      context,
                                      d,
                                      compact: c.maxWidth < 620,
                                    ),
                                  ),
                            ],
                          ),
                    ),
                    ListPager(
                      total: entries.length, page: page, pageSize: pageSize,
                      onPageChanged: (n) => setState(() => currentPage = n),
                      onPageSizeChanged: (n) => setState(() { pageSize = n; currentPage = 0; }),
                    ),

                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );

  Widget _actions(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> item,
  ) => PopupMenuButton<String>(
    tooltip: 'Cari işlemleri',
    onSelected: (action) {
      if (action == 'edit') contactDialog(context, item: item);
      if (action == 'payment') paymentDialog(context, item);
      if (action == 'debt') accountEntryDialog(context, item);
      if (action == 'history') contactHistory(context, item);
    },
    itemBuilder:
        (_) => const [
          PopupMenuItem(value: 'payment', child: Text('Tahsilat / ödeme')),
          PopupMenuItem(
            value: 'debt',
            child: Text('Tarihli manuel borç / alacak gir'),
          ),
          PopupMenuItem(
            value: 'history',
            child: Text('Firma kartı ve hareketler'),
          ),
          PopupMenuItem(value: 'edit', child: Text('Cari düzenle')),
        ],
  );

  Widget _contactEntry(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> item, {
    required bool compact,
  }) {
    final m = item.data();
    final balance = (m['balanceMinor'] as num?)?.toInt() ?? 0;
    final name = '${m['name'] ?? 'Cari'}';
    final kind = switch (m['type']) {
      'customer' => 'Müşteri',
      'supplier' => 'Tedarikçi',
      _ => 'Müşteri / Tedarikçi',
    };
    final status =
        balance > 0
            ? 'Alacak'
            : balance < 0
            ? 'Borç'
            : 'Dengede';
    final color =
        balance > 0
            ? green
            : balance < 0
            ? amber
            : muted;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: softGreen,
                    child: Icon(
                      m['type'] == 'supplier'
                          ? Icons.local_shipping_outlined
                          : Icons.person_outline,
                      color: green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$kind  •  ${m['phone'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  _actions(context, item),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusPill(
                    label: '$status: ${money(balance.abs())}',
                    color: color,
                  ),
                  TextButton.icon(
                    onPressed: () => contactHistory(context, item),
                    icon: const Icon(Icons.badge_outlined, size: 17),
                    label: const Text('Firma kartı'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 1),
          onTap: () => contactHistory(context, item),
          leading: CircleAvatar(
            backgroundColor: softGreen,
            child: Icon(
              m['type'] == 'supplier'
                  ? Icons.local_shipping_outlined
                  : Icons.person_outline,
              color: green,
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
          ),
          subtitle: Text(
            '$kind   •   ${m['phone'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusPill(
                label: '$status ${money(balance.abs())}',
                color: color,
              ),
              const SizedBox(width: 7),
              IconButton(
                onPressed: () => paymentDialog(context, item),
                tooltip: 'Tahsilat / ödeme',
                icon: const Icon(Icons.payments_outlined, color: green),
              ),
              _actions(context, item),
            ],
          ),
        ),
        const Divider(height: 1, color: line),
      ],
    );
  }
}

Future<void> contactDialog(
  BuildContext context, {
  QueryDocumentSnapshot<Map<String, dynamic>>? item,
  String defaultType = 'customer',
}) async {
  final m = item?.data();
  final name = TextEditingController(text: m?['name'] ?? ''),
      phone = TextEditingController(text: m?['phone'] ?? ''),
      email = TextEditingController(text: m?['email'] ?? ''),
      tax = TextEditingController(text: m?['taxNumber'] ?? ''),
      address = TextEditingController(text: m?['address'] ?? ''),
      person = TextEditingController(text: m?['contactPerson'] ?? ''),
      taxOffice = TextEditingController(text: m?['taxOffice'] ?? ''),
      iban = TextEditingController(text: m?['iban'] ?? '');
  String type = m?['type'] ?? defaultType;
  bool busy = false;
  await showOwnedDialog<void>(
    context: context,
    controllers: [name, phone, email, tax, address, person, taxOffice, iban],
    builder:
        (dc) => StatefulBuilder(
          builder:
              (context, update) => ResponsiveFormDialog(
                title: Text(item == null ? 'Cari ekle' : 'Cari düzenle'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Ad / firma ünvanı *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (item == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          type == 'supplier'
                              ? 'Tedarikçi kartı'
                              : 'Müşteri cari kartı',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Cari türü',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'customer',
                            child: Text('Müşteri'),
                          ),
                          DropdownMenuItem(
                            value: 'supplier',
                            child: Text('Tedarikçi'),
                          ),
                          DropdownMenuItem(
                            value: 'both',
                            child: Text('Her ikisi'),
                          ),
                        ],
                        onChanged: (s) => update(() => type = s ?? type),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tax,
                      decoration: const InputDecoration(
                        labelText: 'Vergi / T.C. numarası',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: taxOffice,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Vergi dairesi',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: person,
                      maxLength: 150,
                      decoration: const InputDecoration(
                        labelText: 'İlgili kişi',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: iban,
                      maxLength: 34,
                      decoration: const InputDecoration(labelText: 'IBAN'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: address,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Adres'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dc),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    onPressed:
                        busy
                            ? null
                            : () async {
                              try {
                                if (name.text.trim().isEmpty) {
                                  throw const FormatException(
                                    'Firma adı zorunlu.',
                                  );
                                }
                                update(() => busy = true);
                                final data = {
                                  'name': name.text.trim(),
                                  'type': type,
                                  'phone': phone.text.trim(),
                                  'email': email.text.trim(),
                                  'taxNumber': tax.text.trim(),
                                  'address': address.text.trim(),
                                  'contactPerson': person.text.trim(),
                                  'taxOffice': taxOffice.text.trim(),
                                  'iban': iban.text.trim(),
                                };
                                if (item == null) {
                                  await AppApi.instance.create('contacts', {
                                    ...data,
                                    'balanceMinor': 0,
                                  });
                                } else {
                                  await AppApi.instance.edit(
                                    'contacts',
                                    item.id,
                                    data,
                                  );
                                }
                                if (dc.mounted) Navigator.pop(dc);
                              } catch (e) {
                                if (context.mounted) {
                                  notify(context, '$e', error: true);
                                }
                                update(() => busy = false);
                              }
                            },
                    child: const Text('Kaydet'),
                  ),
                ],
              ),
        ),
  );
}

Future<void> paymentDialog(
  BuildContext context,
  DocumentSnapshot<Map<String, dynamic>> contact, {
  String? accountEntryId,
  int? remainingMinor,
  String? entryKind,
}) async {
  final input = TextEditingController(
        text:
            remainingMinor == null
                ? ''
                : (remainingMinor / 100)
                    .toStringAsFixed(2)
                    .replaceAll('.', ','),
      ),
      note = TextEditingController();
  final contactType = contact.data()!['type'];
  String type =
      entryKind == 'supplierDebt' ||
              (entryKind == null && contactType == 'supplier')
          ? 'payout'
          : 'collection';
  String method = 'cash';
  bool busy = false;
  await showOwnedDialog<void>(
    context: context,
    controllers: [input, note],
    builder:
        (dc) => StatefulBuilder(
          builder:
              (context, update) => ResponsiveFormDialog(
                title: Text(
                  accountEntryId == null
                      ? '${contact.data()!['name']} • Cari hareket'
                      : '${contact.data()!['name']} • Belge ödemesi',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (remainingMinor != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Bu belge için kalan: ${money(remainingMinor)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    if (contactType == 'both' && accountEntryId == null)
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'İşlem'),
                        items: const [
                          DropdownMenuItem(
                            value: 'collection',
                            child: Text('Tahsilat al'),
                          ),
                          DropdownMenuItem(
                            value: 'payout',
                            child: Text('Ödeme yap'),
                          ),
                        ],
                        onChanged: (s) => update(() => type = s ?? type),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          type == 'collection'
                              ? 'Müşteri tahsilatı'
                              : 'Tedarikçi ödemesi',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'Ödeme yöntemi',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                        DropdownMenuItem(value: 'card', child: Text('Kart')),
                      ],
                      onChanged: (s) => update(() => method = s ?? method),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: input,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Tutar (₺)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dc),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    onPressed:
                        busy
                            ? null
                            : () async {
                              try {
                                final amount = parseMoney(input.text);
                                if (amount <= 0) {
                                  throw const FormatException(
                                    'Sıfırdan büyük tutar girin.',
                                  );
                                }
                                update(() => busy = true);
                                await AppApi.instance.call('postPayment', {
                                  'contactId': contact.id,
                                  'type': type,
                                  'amountMinor': amount,
                                  'method': method,
                                  'note': note.text,
                                  'accountEntryId': accountEntryId,
                                });
                                if (dc.mounted) Navigator.pop(dc);
                              } catch (e) {
                                if (context.mounted) {
                                  notify(context, '$e', error: true);
                                }
                                update(() => busy = false);
                              }
                            },
                    child: const Text('İşlemi kaydet'),
                  ),
                ],
              ),
        ),
  );
}

Future<void> accountEntryDialog(
  BuildContext context,
  DocumentSnapshot<Map<String, dynamic>> contact,
) async {
  final amount = TextEditingController(),
      reference = TextEditingController(),
      project = TextEditingController(),
      note = TextEditingController();
  var documentKind = 'opening';
  final today = DateTime.now();
  var date = DateTime(today.year, today.month, today.day);
  DateTime? dueDate;
  var busy = false;
  var kind =
      contact.data()!['type'] == 'supplier'
          ? 'supplierDebt'
          : 'customerReceivable';
  await showOwnedDialog<void>(
    context: context,
    controllers: [amount, reference, project, note],
    builder:
        (dc) => StatefulBuilder(
          builder:
              (context, update) => ResponsiveFormDialog(
                title: Text(
                  kind == 'supplierDebt'
                      ? 'Geçmiş tedarikçi borcu'
                      : 'Geçmiş müşteri alacağı',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Firma: ${contact.data()!['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    if (contact.data()!['type'] == 'both') ...[
                      DropdownButtonFormField<String>(
                        initialValue: kind,
                        decoration: const InputDecoration(
                          labelText: 'Cari yönü',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'supplierDebt',
                            child: Text('Tedarikçiye borç'),
                          ),
                          DropdownMenuItem(
                            value: 'customerReceivable',
                            child: Text('Müşteriden alacak'),
                          ),
                        ],
                        onChanged:
                            (value) => update(() => kind = value ?? kind),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: documentKind,
                      decoration: const InputDecoration(
                        labelText: 'Kayıt türü',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'opening',
                          child: Text('Açılış / geçmiş bakiye'),
                        ),
                        DropdownMenuItem(
                          value: 'invoice',
                          child: Text('Fatura kaydı'),
                        ),
                        DropdownMenuItem(
                          value: 'project',
                          child: Text('Proje borcu'),
                        ),
                      ],
                      onChanged:
                          (value) => update(
                            () => documentKind = value ?? documentKind,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (documentKind == 'invoice')
                      TextField(
                        controller: reference,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Fatura numarası *',
                        ),
                      ),
                    if (documentKind == 'project')
                      TextField(
                        controller: project,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Proje adı *',
                        ),
                      ),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Borç / alacak tutarı (₺) *',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          update(() {
                            date = picked;
                            if (dueDate != null && dueDate!.isBefore(date)) {
                              dueDate = null;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'İşlem tarihi: ${date.day}.${date.month}.${date.year}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? date,
                              firstDate: date,
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) update(() => dueDate = picked);
                          },
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text(
                            dueDate == null
                                ? 'Vade tarihi ekle'
                                : 'Vade: ${dueDate!.day}.${dueDate!.month}.${dueDate!.year}',
                          ),
                        ),
                        if (dueDate != null)
                          TextButton(
                            onPressed: () => update(() => dueDate = null),
                            child: const Text('Vadeyi kaldır'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Açıklama'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bu kayıt stok veya kasa hareketi oluşturmaz; yalnızca cari bakiyeyi günceller.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(dc),
                    child: const Text('İptal'),
                  ),
                  FilledButton(
                    onPressed:
                        busy
                            ? null
                            : () async {
                              try {
                                final minor = parseMoney(amount.text);
                                if (minor <= 0) {
                                  throw const FormatException(
                                    'Sıfırdan büyük tutar girin.',
                                  );
                                }
                                update(() => busy = true);
                                await AppApi.instance
                                    .call('recordAccountEntry', {
                                      'contactId': contact.id,
                                      'kind': kind,
                                      'documentKind': documentKind,
                                      'reference': reference.text,
                                      'projectName': project.text,
                                      'note': note.text,
                                      'amountMinor': minor,
                                      'effectiveAt': date,
                                      'dueAt': dueDate,
                                    });
                                if (dc.mounted) Navigator.pop(dc);
                              } catch (e) {
                                if (context.mounted) {
                                  notify(context, '$e', error: true);
                                }
                                if (dc.mounted) update(() => busy = false);
                              }
                            },
                    child: const Text('Borcu kaydet'),
                  ),
                ],
              ),
        ),
  );
}

Future<void> contactHistory(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> contact,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PartnerCardPage(contactId: contact.id),
    ),
  );
}

class PartnerCardPage extends StatelessWidget {
  const PartnerCardPage({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Firma kartı')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  AppApi.instance
                      .collection('contacts')
                      .doc(contactId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Firma kartı açılamadı: ${snapshot.error}');
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (!snapshot.data!.exists) {
                  return const Text('Firma bulunamadı.');
                }
                final data = snapshot.data!.data()!;
                final balance = (data['balanceMinor'] as num?)?.toInt() ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageTitle(
                      title: (data['name'] ?? 'Firma').toString(),
                      subtitle:
                          data['type'] == 'supplier'
                              ? 'Tedarikçi kartı'
                              : data['type'] == 'customer'
                              ? 'Müşteri cari kartı'
                              : 'Müşteri ve tedarikçi kartı',
                    ),
                    DataPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            balance < 0
                                ? 'Tedarikçiye borç'
                                : balance > 0
                                ? 'Cari alacak'
                                : 'Bakiye',
                            style: const TextStyle(color: muted),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            money(balance.abs()),
                            style: const TextStyle(
                              color: ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    () =>
                                        paymentDialog(context, snapshot.data!),
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Tahsilat / ödeme'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    () => accountEntryDialog(
                                      context,
                                      snapshot.data!,
                                    ),
                                icon: const Icon(Icons.add_card_outlined),
                                label: const Text('Geçmiş borç / alacak'),
                              ),
                            ],
                          ),
                          const Divider(height: 26),
                          _info('İlgili kişi', data['contactPerson']),
                          _info('Telefon', data['phone']),
                          _info('E-posta', data['email']),
                          _info('Vergi numarası', data['taxNumber']),
                          _info('Vergi dairesi', data['taxOffice']),
                          _info('IBAN', data['iban']),
                          _info('Adres', data['address']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _history(snapshot.data!),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _info(String label, dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $text'),
    );
  }

  Widget _history(
    DocumentSnapshot<Map<String, dynamic>> contact,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream:
        AppApi.instance
            .collection('trades')
            .where('contactId', isEqualTo: contactId)
            .snapshots(),
    builder: (context, trades) {
      if (trades.hasError) return Text('İşlemler okunamadı: ${trades.error}');
      if (!trades.hasData) return const LinearProgressIndicator();
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            AppApi.instance
                .collection('payments')
                .where('contactId', isEqualTo: contactId)
                .snapshots(),
        builder: (context, payments) {
          if (payments.hasError) {
            return Text('Ödemeler okunamadı: ${payments.error}');
          }
          if (!payments.hasData) return const LinearProgressIndicator();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                AppApi.instance
                    .collection('accountEntries')
                    .where('contactId', isEqualTo: contactId)
                    .snapshots(),
            builder: (context, entries) {
              if (entries.hasError) {
                return Text('Geçmiş borçlar okunamadı: ${entries.error}');
              }
              if (!entries.hasData) return const LinearProgressIndicator();
              final rows = <Map<String, dynamic>>[
                for (final d in trades.data!.docs)
                  {...d.data(), 'rowKind': 'trade'},
                for (final d in payments.data!.docs)
                  {...d.data(), 'rowKind': 'payment'},
                for (final d in entries.data!.docs)
                  {...d.data(), 'rowKind': 'entry', 'rowId': d.id},
              ]..sort((a, b) => _time(b).compareTo(_time(a)));
              return DataPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(
                      title: 'Hesap hareketleri',
                      subtitle: '${rows.length} kayıt',
                    ),
                    const SizedBox(height: 10),
                    if (rows.isEmpty)
                      const BlankState(
                        message: 'Henüz hesap hareketi yok.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    for (final row in rows.take(100)) ...[
                      Builder(
                        builder: (context) {
                          final remaining =
                              row['rowKind'] == 'entry'
                                  ? ((row['amountMinor'] as num?)?.toInt() ??
                                          0) -
                                      ((row['settledMinor'] as num?)?.toInt() ??
                                          0)
                                  : 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _title(row),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${dateOf(row['rowKind'] == 'entry' ? row['effectiveAt'] : row['createdAt'])}'
                                  '${_detail(row).isEmpty ? '' : ' • ${_detail(row)}'}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tutar: ${money(((row['rowKind'] == 'trade' ? row['totalMinor'] : row['amountMinor']) as num?)?.toInt() ?? 0)}'
                                  '${row['rowKind'] == 'entry' ? ' • Kalan: ${money(remaining)}' : ''}',
                                ),
                                if (row['rowKind'] == 'entry' &&
                                    row['dueAt'] is Timestamp)
                                  Text(
                                    'Vade: ${dateOf(row['dueAt'])}'
                                    '${remaining > 0 && (row['dueAt'] as Timestamp).toDate().isBefore(DateTime.now()) ? ' • Gecikmiş' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          remaining > 0 &&
                                                  (row['dueAt'] as Timestamp)
                                                      .toDate()
                                                      .isBefore(DateTime.now())
                                              ? amber
                                              : muted,
                                    ),
                                  ),
                                if (row['rowKind'] == 'entry' && remaining > 0)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed:
                                          () => paymentDialog(
                                            context,
                                            contact,
                                            accountEntryId:
                                                row['rowId'] as String,
                                            remainingMinor: remaining,
                                            entryKind: row['kind'] as String,
                                          ),
                                      icon: const Icon(
                                        Icons.payments_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Bu belgeye ödeme kaydet',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                    ],
                    if (rows.length > 100)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'İlk 100 kayıt gösteriliyor.',
                          style: TextStyle(color: muted),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );

  int _time(Map<String, dynamic> row) {
    final value =
        row['rowKind'] == 'entry' ? row['effectiveAt'] : row['createdAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }

  String _title(Map<String, dynamic> row) => switch (row['rowKind']) {
    'trade' => row['type'] == 'sale' ? 'Satış fişi' : 'Alış fişi',
    'payment' =>
      row['accountEntryId'] != null
          ? (row['type'] == 'collection' ? 'Belge tahsilatı' : 'Belge ödemesi')
          : (row['type'] == 'collection' ? 'Tahsilat' : 'Tedarikçi ödemesi'),
    _ =>
      row['kind'] == 'supplierDebt'
          ? 'Geçmiş tedarikçi borcu'
          : 'Geçmiş müşteri alacağı',
  };

  String _detail(Map<String, dynamic> row) {
    if (row['rowKind'] == 'entry') {
      final label = switch (row['documentKind']) {
        'invoice' => 'Fatura',
        'project' => 'Proje',
        _ => 'Açılış bakiyesi',
      };
      return [
        label,
        row['reference'],
        row['projectName'],
      ].where((v) => v != null && '$v'.isNotEmpty).join(' • ');
    }
    if (row['rowKind'] == 'trade') return (row['documentNo'] ?? '').toString();
    return (row['method'] ?? 'Yöntem belirtilmedi').toString();
  }
}

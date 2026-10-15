import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../erp/erp_metrics.dart';
import '../erp/finance_ledger.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

const expenseCategories = <String, String>{
  'rent': 'Kira',
  'utilities': 'Faturalar',
  'salary': 'Personel',
  'transport': 'Ulaşım',
  'marketing': 'Pazarlama',
  'other': 'Diğer',
};
const expenseMethods = <String, String>{
  'cash': 'Nakit',
  'card': 'Kart',
  'bank': 'Banka',
};

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  String period = '30', filter = 'all';
  int currentPage = 0, pageSize = 10;
  DateTime? startDate, endDate;
  Future<void> chooseDate(bool start) async {
    final now = DateTime.now();
    final picked = await showPilotDatePicker(
      context: context,
      initialDate: (start ? startDate : endDate) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() {
        period = 'custom';
        if (start) {
          startDate = picked;
        } else {
          endDate = picked;
        }
        currentPage = 0;
      });
    }
  }

  DateTime? get since =>
      period == 'all' || period == 'custom'
          ? null
          : DateTime.now().subtract(Duration(days: int.parse(period)));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageTitle(
        title: 'Finans ve giderler',
        subtitle: 'Tahsilat, tedarikçi ödemesi ve işletme giderlerini izle.',
        action: FilledButton.icon(
          onPressed: () => _expenseDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Gider ekle'),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item
              in const {
                '7': '7 gün',
                '30': '30 gün',
                '90': '90 gün',
                'all': 'Tüm zamanlar',
              }.entries)
            ChoiceChip(
              label: Text(item.value),
              selected: period == item.key,
              onSelected:
                  (_) => setState(() {
                    period = item.key;
                    startDate = null;
                    endDate = null;
                    currentPage = 0;
                  }),
            ),
        ],
      ),
      const SizedBox(height: 10),
      ResponsiveFields(
        first: CompactDateField(
          label: 'Başlangıç tarihi',
          date: startDate,
          onTap: () => chooseDate(true),
          onClear:
              () => setState(() {
                startDate = null;
                period = 'custom';
                currentPage = 0;
              }),
        ),
        second: CompactDateField(
          label: 'Bitiş tarihi',
          date: endDate,
          onTap: () => chooseDate(false),
          onClear:
              () => setState(() {
                endDate = null;
                period = 'custom';
                currentPage = 0;
              }),
        ),
      ),
      const SizedBox(height: 14),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('payments'),
        builder: (context, payments) {
          if (payments.hasError) {
            return DataPanel(
              child: Text('Ödemeler okunamadı: ${payments.error}'),
            );
          }
          if (!payments.hasData) return const LinearProgressIndicator();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppApi.instance.watch('expenses'),
            builder: (context, expenses) {
              if (expenses.hasError) {
                return DataPanel(
                  child: Text('Giderler okunamadı: ${expenses.error}'),
                );
              }
              if (!expenses.hasData) return const LinearProgressIndicator();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppApi.instance.watch('contacts'),
                builder: (context, contacts) {
                  if (contacts.hasError) {
                    return DataPanel(
                      child: Text('Cariler okunamadı: ${contacts.error}'),
                    );
                  }
                  if (!contacts.hasData) return const LinearProgressIndicator();
                  return _content(
                    context,
                    payments.data!.docs,
                    expenses.data!.docs,
                    {
                      for (final d in contacts.data!.docs)
                        d.id: (d.data()['name'] ?? 'Cari').toString(),
                    },
                  );
                },
              );
            },
          );
        },
      ),
    ],
  );

  Widget _content(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    Map<String, String> contacts,
  ) {
    final start = since;
    bool withinRange(Map<String, dynamic> data) {
      if (period != 'custom') return true;
      final value = data['createdAt'];
      final date = value is Timestamp ? value.toDate() : null;
      if (date == null) return false;
      if (startDate != null &&
          date.isBefore(
            DateTime(startDate!.year, startDate!.month, startDate!.day),
          )) {
        return false;
      }
      if (endDate != null &&
          !date.isBefore(
            DateTime(endDate!.year, endDate!.month, endDate!.day + 1),
          )) {
        return false;
      }
      return true;
    }

    final totals = FinanceTotals.compute(
      payments: payments.map((d) => d.data()).where(withinRange),
      expenses: expenses.map((d) => d.data()).where(withinRange),
      since: start,
    );
    bool included(Map<String, dynamic> row) {
      if (!withinRange(row)) return false;
      if (start == null) return true;
      final at = row['createdAt'];
      return at is Timestamp && !at.toDate().isBefore(start);
    }

    final rows = <_LedgerRow>[
      for (final d in payments)
        if (included(d.data()) &&
            (filter == 'all' || filter == d.data()['type']))
          _LedgerRow(
            d.id,
            d.data(),
            d.data()['type'] == 'collection' ? 'Tahsilat' : 'Tedarikçi ödemesi',
            contacts[(d.data()['contactId'] ?? '').toString()] ?? 'Peşin işlem',
            d.data()['type'] == 'collection',
          ),
      for (final d in expenses)
        if (included(d.data()) && (filter == 'all' || filter == 'expense'))
          _LedgerRow(
            d.id,
            d.data(),
            'Gider',
            (d.data()['title'] ?? '').toString(),
            false,
          ),
    ]..sort((a, b) {
      final aTime = a.data['createdAt'], bTime = b.data['createdAt'];
      return (bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0).compareTo(
        aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0,
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final cols =
                box.maxWidth >= 1000
                    ? 4
                    : box.maxWidth >= 520
                    ? 2
                    : 1;
            final width = (box.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: MetricCard(
                    title: 'Tahsilatlar',
                    value: money(totals.collectionsMinor),
                    icon: Icons.call_received_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    title: 'Tedarikçi ödemeleri',
                    value: money(totals.payoutsMinor),
                    icon: Icons.call_made_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    title: 'İşletme giderleri',
                    value: money(totals.expensesMinor),
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    title: 'Net para hareketi',
                    value: money(totals.netMinor),
                    icon: Icons.account_balance_wallet_outlined,
                    subtext: 'Kayıtlı giriş − ödeme − gider',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        DataPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final heading = SectionHeading(
                    title: 'Para hareketleri',
                    subtitle: '${rows.length} kayıt • seçili dönemde',
                  );
                  final export = OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: erpCsv([
                            [
                              'Tarih',
                              'Tür',
                              'Açıklama',
                              'Tutar (kuruş)',
                              'Yöntem',
                              'Not',
                            ],
                            for (final row in rows)
                              [
                                dateOf(row.data['createdAt']),
                                row.kind,
                                row.label,
                                row.data['amountMinor'] ?? 0,
                                expenseMethods[row.data['method']] ??
                                    row.data['method'] ??
                                    '',
                                row.data['note'] ?? '',
                              ],
                          ]),
                        ),
                      );
                      if (context.mounted) {
                        notify(
                          context,
                          'Para hareketleri CSV olarak panoya kopyalandı.',
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('CSV kopyala'),
                  );
                  if (box.maxWidth < 470) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [heading, const SizedBox(height: 12), export],
                    );
                  }
                  return Row(children: [Expanded(child: heading), export]);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  for (final item
                      in const {
                        'all': 'Tümü',
                        'collection': 'Tahsilat',
                        'payout': 'Ödeme',
                        'expense': 'Gider',
                      }.entries)
                    ChoiceChip(
                      label: Text(item.value),
                      selected: filter == item.key,
                      onSelected:
                          (_) => setState(() {
                            filter = item.key;
                            currentPage = 0;
                          }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const BlankState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Hareket bulunamadı',
                  message: 'Dönemi değiştir veya yeni bir gider kaydet.',
                ),
              for (final row in rows
                  .skip(
                    currentPage.clamp(
                          0,
                          ((rows.length + pageSize - 1) ~/ pageSize).clamp(
                                1,
                                999999,
                              ) -
                              1,
                        ) *
                        pageSize,
                  )
                  .take(pageSize)) ...[
                LayoutBuilder(
                  builder: (context, box) {
                    final amount =
                        (row.data['amountMinor'] as num?)?.toInt() ?? 0;
                    final subtitle =
                        '${dateOf(row.data['createdAt'])} • ${row.kind}'
                        '${row.kind == 'Gider' ? ' • ${expenseCategories[row.data['category']] ?? 'Diğer'}' : ''}';
                    if (box.maxWidth < 460) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${row.inflow ? '+' : '−'}${money(amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: row.inflow ? green : amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 3),
                      leading: CircleAvatar(
                        backgroundColor:
                            row.inflow ? softGreen : const Color(0xFFFFF3E4),
                        child: Icon(
                          row.inflow
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: row.inflow ? green : amber,
                        ),
                      ),
                      title: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${row.inflow ? '+' : '−'}${money(amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: row.inflow ? green : amber,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
              ],
              ListPager(
                total: rows.length,
                page: currentPage,
                pageSize: pageSize,
                onPageChanged: (n) => setState(() => currentPage = n),
                onPageSizeChanged:
                    (n) => setState(() {
                      pageSize = n;
                      currentPage = 0;
                    }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _expenseDialog(BuildContext context) async {
    final title = TextEditingController(),
        amount = TextEditingController(),
        note = TextEditingController();
    var category = 'other', method = 'cash', busy = false;
    await showOwnedDialog<void>(
      context: context,
      controllers: [title, amount, note],
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, update) => ResponsiveFormDialog(
                  title: const Text('Yeni gider'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Gider adı *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                        ),
                        items: [
                          for (final item in expenseCategories.entries)
                            DropdownMenuItem(
                              value: item.key,
                              child: Text(item.value),
                            ),
                        ],
                        onChanged:
                            (value) =>
                                update(() => category = value ?? category),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(
                          labelText: 'Ödeme yöntemi',
                        ),
                        items: [
                          for (final item in expenseMethods.entries)
                            DropdownMenuItem(
                              value: item.key,
                              child: Text(item.value),
                            ),
                        ],
                        onChanged:
                            (value) => update(() => method = value ?? method),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tutar (₺) *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: note,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Not (isteğe bağlı)',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          busy ? null : () => Navigator.pop(dialogContext),
                      child: const Text('İptal'),
                    ),
                    FilledButton(
                      onPressed:
                          busy
                              ? null
                              : () async {
                                try {
                                  final minor = parseMoney(amount.text);
                                  if (title.text.trim().isEmpty || minor <= 0) {
                                    throw const FormatException(
                                      'Gider adı ve sıfırdan büyük tutar girin.',
                                    );
                                  }
                                  update(() => busy = true);
                                  await AppApi.instance.call('recordExpense', {
                                    'title': title.text,
                                    'category': category,
                                    'method': method,
                                    'amountMinor': minor,
                                    'note': note.text,
                                  });
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    notify(context, '$error', error: true);
                                  }
                                  if (dialogContext.mounted) {
                                    update(() => busy = false);
                                  }
                                }
                              },
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
          ),
    );
  }
}

class _LedgerRow {
  const _LedgerRow(this.id, this.data, this.kind, this.label, this.inflow);
  final String id, kind, label;
  final Map<String, dynamic> data;
  final bool inflow;
}

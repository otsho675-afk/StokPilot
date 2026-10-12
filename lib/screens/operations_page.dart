import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../erp/erp_metrics.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

/// Unified, read-only ERP journal. All changes still go through the existing
/// validated sale/purchase/stock transactions and Firebase security rules.
class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});
  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  int tab = 0;
  String filter = 'all';
  String search = '';
  int visible = 60;

  void setTab(int value) => setState(() {
    tab = value;
    filter = 'all';
    search = '';
    visible = 60;
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageTitle(
        title: 'ERP İşlem Merkezi',
        subtitle: 'Satış, alış ve stok hareketlerinin izlenebilir operasyon kaydı.',
      ),
      Wrap(
        spacing: 9,
        runSpacing: 8,
        children: [
          ChoiceChip(
            selected: tab == 0,
            onSelected: (_) => setTab(0),
            avatar: const Icon(Icons.receipt_long_outlined, size: 17),
            label: const Text('Satış & alış defteri'),
          ),
          ChoiceChip(
            selected: tab == 1,
            onSelected: (_) => setTab(1),
            avatar: const Icon(Icons.swap_vert_rounded, size: 17),
            label: const Text('Stok hareketleri'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      DataPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('erp-search-$tab'),
            onChanged: (value) => setState(() {
              search = value.toLowerCase().trim();
              visible = 60;
            }),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              labelText: tab == 0
                  ? 'İşlem, cari veya not ara'
                  : 'Ürün, açıklama veya hareket ara',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _filterChip('all', 'Tümü'),
            if (tab == 0) ...[
              _filterChip('sale', 'Satışlar'),
              _filterChip('purchase', 'Alışlar'),
            ] else ...[
              _filterChip('sale', 'Satış çıkışı'),
              _filterChip('purchase', 'Alış girişi'),
              _filterChip('adjustment', 'Düzeltmeler'),
            ],
          ]),
        ],
      )),
      const SizedBox(height: 14),
      if (tab == 0) _trades() else _moves(),
    ],
  );

  Widget _filterChip(String value, String text) => ChoiceChip(
    selected: filter == value,
    onSelected: (_) => setState(() { filter = value; visible = 60; }),
    label: Text(text),
  );

  Future<void> _copyCsv(BuildContext context, List<List<Object?>> rows) async {
    await Clipboard.setData(ClipboardData(text: erpCsv(rows)));
    if (context.mounted) {
      notify(context, '${rows.length - 1} kayıt CSV olarak panoya kopyalandı.');
    }
  }

  Widget _trades() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.watch('trades'),
    builder: (context, tradeSnapshot) {
      if (tradeSnapshot.hasError) {
        return _failure('İşlem kayıtları okunamadı: ${tradeSnapshot.error}');
      }
      if (!tradeSnapshot.hasData) return const LinearProgressIndicator();
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('contacts'),
        builder: (context, contactSnapshot) {
          if (contactSnapshot.hasError) {
            return _failure('Cari bilgileri okunamadı: ${contactSnapshot.error}');
          }
          if (!contactSnapshot.hasData) return const LinearProgressIndicator();
          final contacts = {
            for (final doc in contactSnapshot.data!.docs)
              doc.id: (doc.data()['name'] ?? '').toString(),
          };
          final records = tradeSnapshot.data!.docs.where((doc) {
            final data = doc.data();
            if (filter != 'all' && data['type'] != filter) return false;
            final contact = contacts[(data['contactId'] ?? '').toString()] ?? 'Peşin işlem';
            return search.isEmpty ||
                '$contact ${data['note'] ?? ''} ${doc.id}'.toLowerCase().contains(search) ||
                ((data['lines'] as List?) ?? []).any((raw) =>
                  raw is Map && '${raw['name'] ?? ''}'.toLowerCase().contains(search));
          }).toList()..sort((a,b) => _order(b.data()['createdAt'])
              .compareTo(_order(a.data()['createdAt'])));
          final total = records.fold<int>(0, (sum, doc) =>
              sum + _minor(doc.data()['totalMinor']));
          final shown = records.take(visible).toList();
          return DataPanel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _journalHeading(context, 'İşlem kayıtları',
                '${records.length} işlem • ${money(total)} toplam hacim',
                onCopy: () => _copyCsv(context, [
                  ['Tarih', 'Tür', 'Cari', 'Ara toplam (kuruş)', 'KDV (kuruş)',
                   'Toplam (kuruş)', 'Ödenen (kuruş)', 'Not'],
                  ...records.map((doc) {
                    final row = doc.data();
                    return [dateOf(row['createdAt']), row['type'],
                      contacts[(row['contactId'] ?? '').toString()] ?? 'Peşin',
                      _minor(row['netMinor']), _minor(row['taxMinor']),
                      _minor(row['totalMinor']), _minor(row['paidMinor']),
                      row['note'] ?? ''];
                  }),
                ])),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const BlankState(icon: Icons.receipt_long_outlined,
                  title: 'İşlem bulunamadı', message: 'Filtreyi değiştir veya satış/alış kaydı oluştur.'),
              ...shown.map((doc) {
                final row = doc.data();
                final isSale = row['type'] == 'sale';
                final name = contacts[(row['contactId'] ?? '').toString()] ?? 'Peşin işlem';
                final amount = _minor(row['totalMinor']);
                final paid = _minor(row['paidMinor']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Material(
                    color: canvas,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => _TradeDetail(
                          record: row, contactName: name, id: doc.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(children: [
                          _typeIcon(isSale ? Icons.arrow_upward : Icons.arrow_downward,
                              isSale ? green : amber),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$name • ${isSale ? 'Satış' : 'Alış'}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${dateOf(row['createdAt'])}  •  '
                                   'Kalan ${money(amount - paid)}',
                                style: const TextStyle(fontSize: 12, color: muted)),
                            ],
                          )),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(money(amount), style: const TextStyle(
                                fontWeight: FontWeight.w900, color: ink)),
                              const Icon(Icons.chevron_right, size: 18, color: muted),
                            ]),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
              if (records.length > visible) _more(records.length),
            ],
          ));
        },
      );
    },
  );

  Widget _moves() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: AppApi.instance.watch('stockMoves'),
    builder: (context, moveSnapshot) {
      if (moveSnapshot.hasError) {
        return _failure('Stok hareketleri okunamadı: ${moveSnapshot.error}');
      }
      if (!moveSnapshot.hasData) return const LinearProgressIndicator();
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('products'),
        builder: (context, productSnapshot) {
          if (productSnapshot.hasError) {
            return _failure('Ürünler okunamadı: ${productSnapshot.error}');
          }
          if (!productSnapshot.hasData) return const LinearProgressIndicator();
          final products = {
            for (final doc in productSnapshot.data!.docs)
              doc.id: (doc.data()['name'] ?? 'Ürün').toString(),
          };
          final records = moveSnapshot.data!.docs.where((doc) {
            final row = doc.data();
            if (filter != 'all' && row['reason'] != filter) return false;
            final name = products[(row['productId'] ?? '').toString()] ?? 'Silinmiş ürün';
            return search.isEmpty || '$name ${row['note'] ?? ''} ${row['reason'] ?? ''}'
                .toLowerCase().contains(search);
          }).toList()..sort((a,b) => _order(b.data()['createdAt'])
              .compareTo(_order(a.data()['createdAt'])));
          final shown = records.take(visible).toList();
          return DataPanel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _journalHeading(context, 'Stok hareket defteri',
                '${records.length} hareket • giriş / çıkış / düzeltme',
                onCopy: () => _copyCsv(context, [
                  ['Tarih', 'Ürün', 'İşlem', 'Miktar (x1000)', 'Açıklama', 'İşlem ID'],
                  ...records.map((doc) {
                    final m = doc.data();
                    return [dateOf(m['createdAt']),
                      products[(m['productId'] ?? '').toString()] ?? 'Silinmiş ürün',
                      m['reason'] ?? '', _minor(m['deltaMilli']),
                      m['note'] ?? '', m['tradeId'] ?? ''];
                  }),
                ])),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const BlankState(icon: Icons.swap_vert_rounded,
                  title: 'Stok hareketi bulunamadı',
                  message: 'Stok giriş/çıkış veya satış–alış işleminden sonra burada görüntülenir.'),
              ...shown.map((doc) {
                final row = doc.data();
                final delta = _minor(row['deltaMilli']);
                final positive = delta >= 0;
                final name = products[(row['productId'] ?? '').toString()] ?? 'Silinmiş ürün';
                final type = switch (row['reason']) {
                  'sale' => 'Satış çıkışı',
                  'purchase' => 'Alış girişi',
                  _ => 'Manuel düzeltme',
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Container(
                    decoration: BoxDecoration(color: canvas,
                      borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      _typeIcon(positive ? Icons.add_rounded : Icons.remove_rounded,
                        positive ? green : amber),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('$type • ${dateOf(row['createdAt'])}',
                            style: const TextStyle(color: muted, fontSize: 12)),
                          if ((row['note'] ?? '').toString().isNotEmpty)
                            Text('${row['note']}', maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: muted, fontSize: 12)),
                        ])),
                      const SizedBox(width: 7),
                      Text('${positive ? '+' : '−'}${quantity(delta.abs())}',
                        style: TextStyle(fontWeight: FontWeight.w900,
                          color: positive ? green : amber)),
                    ]),
                  ),
                );
              }),
              if (records.length > visible) _more(records.length),
            ],
          ));
        },
      );
    },
  );

  Widget _more(int count) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextButton(
      onPressed: () => setState(() => visible += 60),
      child: Text('Daha fazla göster (${count - visible} kaldı)'),
    ),
  );

  Widget _journalHeading(BuildContext context, String title, String sub,
      {required VoidCallback onCopy}) => LayoutBuilder(builder: (context, box) {
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(color: muted, fontSize: 12)),
    ]);
    final action = OutlinedButton.icon(
      onPressed: onCopy,
      icon: const Icon(Icons.copy_all_outlined, size: 17),
      label: const Text('CSV kopyala'),
    );
    if (box.maxWidth < 450) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading, const SizedBox(height: 10), action,
      ]);
    }
    return Row(children: [Expanded(child: heading), action]);
  });

  Widget _failure(String message) => DataPanel(child: Text(message,
    style: const TextStyle(color: Color(0xFFB73232))));
}

int _minor(dynamic value) => value is num ? value.toInt() : 0;
int _order(dynamic value) => value is Timestamp ? value.millisecondsSinceEpoch : 0;

Widget _typeIcon(IconData icon, Color color) => Container(
  width: 40, height: 40,
  decoration: BoxDecoration(color: color.withValues(alpha: .10),
    borderRadius: BorderRadius.circular(12)),
  child: Icon(icon, color: color, size: 21),
);

class _TradeDetail extends StatelessWidget {
  const _TradeDetail({required this.record, required this.contactName, required this.id});
  final Map<String, dynamic> record;
  final String contactName, id;

  @override
  Widget build(BuildContext context) {
    final lines = (record['lines'] as List?) ?? [];
    final total = _minor(record['totalMinor']);
    final paid = _minor(record['paidMinor']);
    return Scaffold(
      appBar: AppBar(title: Text(record['type'] == 'sale' ? 'Satış detayı' : 'Alış detayı')),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contactName, style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(dateOf(record['createdAt']), style: const TextStyle(color: muted)),
                const SizedBox(height: 12),
                Text('İşlem no: $id', style: const TextStyle(color: muted, fontSize: 12)),
              ])),
            const SizedBox(height: 14),
            DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('İşlem kalemleri', style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 10),
                ...lines.whereType<Map>().map((raw) {
                  final line = Map<String, dynamic>.from(raw);
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${line['name'] ?? 'Ürün'}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${quantity(_minor(line['quantityMilli']))} × '
                            '${money(_minor(line['priceMinor']))}  •  KDV %'
                            '${_minor(line['taxBps']) / 100}',
                            style: const TextStyle(color: muted, fontSize: 12)),
                        ])),
                      Text(money(_minor(line['totalMinor'])),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    ]),
                  );
                }),
              ])),
            const SizedBox(height: 14),
            DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _amountLine('Ara toplam', _minor(record['netMinor'])),
                _amountLine('KDV', _minor(record['taxMinor'])),
                const Divider(),
                _amountLine('GENEL TOPLAM', total, prominent: true),
                _amountLine('Ödenen', paid),
                _amountLine('Açık bakiye', total - paid),
                if ((record['note'] ?? '').toString().isNotEmpty) ...[
                  const Divider(),
                  Text('Açıklama: ${record['note']}'),
                ],
              ])),
          ]),
        )),
      )),
    );
  }

  Widget _amountLine(String text, int amount, {bool prominent = false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(
          fontWeight: prominent ? FontWeight.w900 : FontWeight.w500))),
        Text(money(amount), style: TextStyle(
          fontSize: prominent ? 20 : 15,
          fontWeight: FontWeight.w900, color: ink)),
      ]),
    );
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/global_search.dart';
import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

class SearchSelection {
  const SearchSelection(this.item, [this.document]);
  final SearchItem item;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;
}

class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({super.key});

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final _controller = TextEditingController();
  late final Future<List<QuerySnapshot<Map<String, dynamic>>>> _records =
      Future.wait([
        AppApi.instance.collection('products').get(),
        AppApi.instance.collection('contacts').get(),
        AppApi.instance.collection('trades').get(),
      ]);
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _text(Map<String, dynamic> data, String key) =>
      (data[key] ?? '').toString().trim();

  List<SearchSelection> _items(List<QuerySnapshot<Map<String, dynamic>>> data) {
    final entries = <SearchSelection>[];
    for (final doc in data[0].docs) {
      final value = doc.data();
      entries.add(
        SearchSelection(
          SearchItem(
            id: doc.id,
            kind: SearchKind.product,
            title: _text(value, 'name'),
            subtitle:
                'Ürün • Stok ${quantity((value['stockMilli'] as num?)?.toInt() ?? 0)}',
            keywords: [_text(value, 'sku'), _text(value, 'barcode')],
          ),
          doc,
        ),
      );
    }
    for (final doc in data[1].docs) {
      final value = doc.data();
      final supplier = value['type'] == 'supplier';
      entries.add(
        SearchSelection(
          SearchItem(
            id: doc.id,
            kind: supplier ? SearchKind.supplier : SearchKind.customer,
            title: _text(value, 'name'),
            subtitle: supplier ? 'Tedarikçi kartı' : 'Müşteri cari kartı',
            keywords: [
              _text(value, 'phone'),
              _text(value, 'email'),
              _text(value, 'taxNumber'),
              _text(value, 'contactPerson'),
            ],
          ),
          doc,
        ),
      );
    }
    for (final doc in data[2].docs) {
      final value = doc.data();
      final sale = value['type'] == 'sale';
      entries.add(
        SearchSelection(
          SearchItem(
            id: doc.id,
            kind: sale ? SearchKind.sale : SearchKind.purchase,
            title:
                _text(value, 'documentNo').isNotEmpty
                    ? _text(value, 'documentNo')
                    : (sale ? 'Satış fişi' : 'Alış fişi'),
            subtitle:
                '${sale ? 'Satış' : 'Alış'} • ${money((value['totalMinor'] as num?)?.toInt() ?? 0)}',
            keywords: [
              _text(value, 'contactName'),
              _text(value, 'externalNo'),
              _text(value, 'note'),
              _text(value, 'projectName'),
            ],
          ),
          doc,
        ),
      );
    }
    return entries;
  }

  static IconData _icon(SearchKind kind) => switch (kind) {
    SearchKind.product => Icons.inventory_2_outlined,
    SearchKind.customer => Icons.person_outline_rounded,
    SearchKind.supplier => Icons.local_shipping_outlined,
    SearchKind.sale => Icons.receipt_long_outlined,
    SearchKind.purchase => Icons.shopping_bag_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 600 ? 10 : 24,
        vertical: size.width < 600 ? 12 : 32,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: size.height * .85,
        ),
        child: SizedBox(
          height: size.height < 630 ? size.height * .85 : 550,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 8, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hızlı ara',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Ürün, barkod, firma, telefon veya fiş ara',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: line),
              Expanded(
                child: FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
                  future: _records,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Arama verileri yüklenemedi: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_query.trim().isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Ad, barkod, SKU, telefon, vergi numarası veya fiş numarası yazın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                        ),
                      );
                    }
                    final all = _items(snapshot.data!);
                    final found = findAcrossWorkspace(
                      all.map((e) => e.item),
                      _query,
                    );
                    if (found.isEmpty) {
                      return const Center(
                        child: Text(
                          'Eşleşen kayıt bulunamadı.',
                          style: TextStyle(color: muted),
                        ),
                      );
                    }
                    final byKey = {
                      for (final entry in all)
                        '${entry.item.kind.name}:${entry.item.id}': entry,
                    };
                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: found.length,
                      separatorBuilder:
                          (_, _) => const Divider(height: 1, color: line),
                      itemBuilder: (context, index) {
                        final item = found[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: softGreen,
                            child: Icon(
                              _icon(item.kind),
                              size: 19,
                              color: green,
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: muted,
                          ),
                          onTap:
                              () => Navigator.pop(
                                context,
                                byKey['${item.kind.name}:${item.id}'],
                              ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

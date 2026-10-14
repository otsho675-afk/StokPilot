import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/sales_tools.dart';
import '../services/app_api.dart';
import '../services/review_prompt.dart';
import '../widgets/ui.dart';

class _Line {
  _Line(this.id, this.name, this.qtyMilli, this.priceMinor, this.taxBps, [int? productVat])
      : productTaxBps = productVat ?? taxBps;
  String id, name;
  int qtyMilli, priceMinor, taxBps;
  final int productTaxBps;
  int get net => (qtyMilli * priceMinor / 1000).round();
  int get tax => (net * taxBps / 10000).round();
  int get total => net + tax;
  Map<String, dynamic> get json => {
    'productId': id,
    'quantityMilli': qtyMilli,
    'priceMinor': priceMinor,
    'taxBps': taxBps,
  };
}

class TradesPage extends StatefulWidget {
  const TradesPage({super.key, required this.type});
  final String type;
  @override
  State<TradesPage> createState() => _TradesPageState();
}

class _TradesPageState extends State<TradesPage> {
  final lines = <_Line>[];
  final paid = TextEditingController(),
      note = TextEditingController(),
      externalNo = TextEditingController(),
      projectName = TextEditingController();
  String contactId = '';
  String saleMethod = 'cash';
  String purchaseMethod = 'cash', documentKind = 'receipt';
  bool addVatToSale = false;
  bool busy = false;
  bool get sale => widget.type == 'sale';
  int get total => lines.fold(0, (s, line) => s + line.total);
  void _setSaleVat(bool enabled) {
    setState(() {
      addVatToSale = enabled;
      for (final line in lines) {
        line.taxBps = enabled ? line.productTaxBps : 0;
      }
    });
  }
  int get cartVatMinor => lines.fold<int>(0, (totalVat, line) => totalVat + line.tax);
  int get cartUnitMilli => lines.fold<int>(0, (totalQty, line) => totalQty + line.qtyMilli);

  @override
  void dispose() {
    paid.dispose();
    note.dispose();
    externalNo.dispose();
    projectName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageTitle(
        title: sale ? 'Satış ekranı' : 'Tedarikçi alışı',
        subtitle:
            sale
                ? 'Ürün seç, miktarı belirle ve stoğu otomatik güncelle.'
                : 'Alış kaydını gir, stoklarını anında artır.',
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('products'),
        builder: (context, productSnap) {
          if (productSnap.hasError) {
            return DataPanel(
              child: Text('Ürünler okunamadı: ${productSnap.error}'),
            );
          }
          if (!productSnap.hasData) return const LinearProgressIndicator();
          final products =
              productSnap.data!.docs
                  .where((d) => d.data()['isActive'] != false)
                  .toList();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppApi.instance.watch('contacts'),
            builder: (context, contactSnap) {
              if (contactSnap.hasError) {
                return DataPanel(
                  child: Text('Firmalar okunamadı: ${contactSnap.error}'),
                );
              }
              if (!contactSnap.hasData) return const LinearProgressIndicator();
              final contacts =
                  contactSnap.data!.docs
                      .where(
                        (d) =>
                            d.data()['type'] == 'both' ||
                            d.data()['type'] ==
                                (sale ? 'customer' : 'supplier'),
                      )
                      .toList();
              return DataPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(
                      title:
                          sale ? 'Akıllı kasa' : 'Yeni alış oluştur',
                      subtitle:
                          sale
                              ? 'Ürünleri soldan seç, sağdan ödemeyi tamamla. Hızlı, temiz, tek ekran.'
                              : 'Ürünleri ekle, tedarikçiyi seç ve stok girişini kaydet.',
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, viewport) {
                        final desktopPos = viewport.maxWidth >= 900;
                        final basket = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFD),
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('KASA · ÜRÜNLER', style: TextStyle(
                                color: muted, fontSize: 11, letterSpacing: 1.2,
                                fontWeight: FontWeight.w900)),
                              const SizedBox(height: 14),
                    _posStep(1, 'Ürün seçimi', 'Barkod, stok kodu veya ürün adıyla hızlıca bul.', Icons.search_rounded),
                    const SizedBox(height: 14),
                    Autocomplete<QueryDocumentSnapshot<Map<String, dynamic>>>(
                      displayStringForOption:
                          (product) =>
                              (product.data()['name'] ?? '').toString(),
                      optionsBuilder: (value) {
                        final entries = products
                            .where((p) => !lines.any((line) => line.id == p.id))
                            .map((p) {
                              final m = p.data();
                              return ProductSearchEntry(
                                id: p.id,
                                name: (m['name'] ?? '').toString(),
                                sku: (m['sku'] ?? '').toString(),
                                barcode: (m['barcode'] ?? '').toString(),
                                stockMilli:
                                    (m['stockMilli'] as num?)?.toInt() ?? 0,
                              );
                            });
                        final ranked = findProducts(entries, value.text);
                        final byId = {for (final p in products) p.id: p};
                        return ranked.map((entry) => byId[entry.id]!).toList();
                      },
                      onSelected: (p) async {
                        final item = await _addLineDialog(context, p, sale, addVatToSale);
                        if (mounted && item != null) {
                          setState(() => lines.add(item));
                        }
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final result = options.toList();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 7,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: SizedBox(
                              width:
                                  (MediaQuery.sizeOf(context).width - 32)
                                      .clamp(220.0, 520.0)
                                      .toDouble(),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 300,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: result.length,
                                  itemBuilder: (context, index) {
                                    final product = result[index];
                                    final m = product.data();
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: green,
                                      ),
                                      title: Text(
                                        (m['name'] ?? '').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        'Barkod: ${m['barcode'] ?? '—'} • Stok: ${quantity((m['stockMilli'] as num?)?.toInt() ?? 0)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        money(
                                          (m[sale
                                                          ? 'salePriceMinor'
                                                          : 'purchasePriceMinor']
                                                      as num?)
                                                  ?.toInt() ??
                                              0,
                                        ),
                                      ),
                                      onTap: () => onSelected(product),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder:
                          (ctx, controller, focus, onSubmit) => TextField(
                            controller: controller,
                            focusNode: focus,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Ürün adı, barkod veya stok kodu yazın',
                              labelText: 'Ürün ara',
                              prefixIcon: Icon(Icons.qr_code_scanner_outlined),
                              suffixIcon: Icon(Icons.search),
                              helperText: 'Sonuçtan bir ürüne dokunarak sepete ekleyin.',
                            ),
                          ),
                    ),
                    const SizedBox(height: 14),
                    if (lines.isNotEmpty) ...[
                      Container(
                        key: const ValueKey('pos-cart-summary'),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF102338),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AKTİF SEPET',
                              style: TextStyle(color: Color(0xFFD4E4FF),
                                fontWeight: FontWeight.w800, fontSize: 11,
                                letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text(money(total),
                              style: const TextStyle(color: Colors.white,
                                fontSize: 29, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 7),
                            Wrap(spacing: 12, runSpacing: 7, children: [
                              Text('${lines.length} ürün kalemi',
                                style: const TextStyle(color: Color(0xFFE8F1FF))),
                              Text('Miktar: ${quantity(cartUnitMilli)}',
                                style: const TextStyle(color: Color(0xFFDBEEE9))),
                              Text('KDV: ${money(cartVatMinor)}',
                                style: const TextStyle(color: Color(0xFFDBEEE9))),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (lines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sepet · ${lines.length} ürün',
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  busy
                                      ? null
                                      : () async {
                                        final approved = await confirm(
                                          context,
                                          'Sepeti temizle',
                                          'Kaydedilmemiş ${lines.length} kalem silinsin mi?',
                                        );
                                        if (approved && mounted) {
                                          setState(() => lines.clear());
                                        }
                                      },
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 18,
                              ),
                              label: const Text('Sepeti temizle'),
                            ),
                          ],
                        ),
                      ),
                    if (lines.isEmpty)
                      const BlankState(
                        title: 'Sepet boş, satışa hazır',
                        message:
                            'Yukarıdaki arama alanına ürün adı, stok kodu veya barkod girin.',
                        icon: Icons.shopping_basket_outlined,
                      ),
                    ...lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: canvas,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE1E8F2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: ink,
                                      ),
                                    ),
                                    Text(
                                      '${quantity(line.qtyMilli)} × ${money(line.priceMinor)} • KDV %${line.taxBps / 100}',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Miktarı 1 azalt',
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 33,
                                            minHeight: 33,
                                          ),
                                          onPressed:
                                              busy || line.qtyMilli <= 1000
                                                  ? null
                                                  : () => setState(
                                                    () => line.qtyMilli -= 1000,
                                                  ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 21,
                                            color: green,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            quantity(line.qtyMilli),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: ink,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Miktarı 1 artır',
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 33,
                                            minHeight: 33,
                                          ),
                                          onPressed:
                                              busy
                                                  ? null
                                                  : () => setState(
                                                    () => line.qtyMilli += 1000,
                                                  ),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 21,
                                            color: green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      money(line.total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Ürünü çıkar',
                                onPressed:
                                    () => setState(() => lines.remove(line)),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                            ],
                          ),
                        );
                        final checkout = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(
                              color: Color(0x080F2742), blurRadius: 24,
                              offset: Offset(0, 8))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('ÖDEME PANELİ', style: TextStyle(
                                color: muted, fontSize: 11, letterSpacing: 1.2,
                                fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                    const Divider(),
                    _totalRow(
                      'Matrah',
                      money(lines.fold(0, (s, l) => s + l.net)),
                    ),
                    const SizedBox(height: 5),
                    _totalRow('KDV', money(lines.fold(0, (s, l) => s + l.tax))),
                    const SizedBox(height: 8),
                    _totalRow('Genel toplam', money(total), highlight: true),
                    const SizedBox(height: 16),
                    _posStep(2, 'Müşteri ve belge', 'Cari hesabı, belge türünü ve vergi tercihini belirle.', Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('${widget.type}-$contactId'),
                      initialValue: contactId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: sale ? 'Müşteri / Cari' : 'Tedarikçi / Cari',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Cari olmadan (peşin)'),
                        ),
                        ...contacts.map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.data()['name'] ?? ''),
                          ),
                        ),
                      ],
                      onChanged:
                          (s) => setState(() {
                            contactId = s ?? '';
                            if (contactId.isEmpty) {
                              if (purchaseMethod == 'credit') {
                                purchaseMethod = 'cash';
                              }
                              if (saleMethod == 'credit') {
                                saleMethod = 'cash';
                              }
                            }
                          }),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: documentKind,
                      decoration: const InputDecoration(
                        labelText: 'Belge türü',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'receipt',
                          child: Text('Satış / alış fişi'),
                        ),
                        DropdownMenuItem(
                          value: 'invoice',
                          child: Text('Fatura kaydı'),
                        ),
                        DropdownMenuItem(
                          value: 'project',
                          child: Text('Proje işlemi'),
                        ),
                      ],
                      onChanged:
                          (value) => setState(
                            () => documentKind = value ?? documentKind,
                          ),
                    ),
                    if (documentKind == 'invoice') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: externalNo,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Mevcut fatura numarası *',
                          helperText:
                              'Resmî fatura oluşturmaz; fatura bilgisini kaydeder.',
                        ),
                      ),
                    ],
                    if (documentKind == 'project') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: projectName,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Proje adı *',
                        ),
                      ),
                    ],
                    if (sale)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Satışa KDV ekle',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(addVatToSale
                            ? 'Üründeki KDV oranı satış tutarına ayrıca eklenir.'
                            : 'Kapalı: Ürüne yazdığın satış fiyatı aynen alınır.'),
                          value: addVatToSale,
                          onChanged: busy ? null : _setSaleVat,
                        ),
                      ),
                    const SizedBox(height: 14),
                    _posStep(3, 'Ödeme ve tamamlama', 'Ödeme yöntemini seçip fişi kaydet.', Icons.payments_outlined),
                    const SizedBox(height: 14),
                    if (sale) ...[
                      const Text(
                        'ÖDEME YÖNTEMİ',
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _methodChoice(
                            'cash',
                            'Nakit',
                            Icons.payments_outlined,
                          ),
                          _methodChoice(
                            'card',
                            'Kart',
                            Icons.credit_card_outlined,
                          ),
                          _methodChoice(
                            'credit',
                            'Veresiye',
                            Icons.receipt_long_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              saleMethod == 'credit'
                                  ? const Color(0xFFFFF6E9)
                                  : const Color(0xFFEAF8F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          saleMethod == 'credit'
                              ? (contactId.isEmpty
                                  ? 'Veresiye için önce müşteri/cari seçin.'
                                  : 'Tutar tahsil edilmeden cari hesabın alacağına eklenecek.')
                              : 'Tahsil edilecek: ${money(total)} • ${paymentMethodLabel(saleMethod)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'ALIŞ ÖDEME YÖNTEMİ',
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _purchaseChoice(
                            'cash',
                            'Nakit',
                            Icons.payments_outlined,
                          ),
                          _purchaseChoice(
                            'card',
                            'Kart',
                            Icons.credit_card_outlined,
                          ),
                          if (contactId.isNotEmpty)
                            _purchaseChoice(
                              'credit',
                              'Veresiye',
                              Icons.receipt_long_outlined,
                            ),
                        ],
                      ),
                      if (contactId.isNotEmpty &&
                          purchaseMethod != 'credit') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: paid,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'İlk ödeme (₺)',
                            helperText:
                                'Boş bırakılırsa tamamı ödenir; kısmi ödeme yazılabilir.',
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'İşlem notu (opsiyonel)',
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          busy
                              ? 'Kaydediliyor...'
                              : (sale ? 'Satışı tamamla' : 'Alışı tamamla'),
                        ),
                        onPressed: busy || lines.isEmpty ? null : save,
                      ),
                    ),

                            ],
                          ),
                        );
                        if (!desktopPos) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [basket, const SizedBox(height: 16), checkout],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: basket),
                            const SizedBox(width: 18),
                            Expanded(flex: 4, child: checkout),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      const SizedBox(height: 22),
      Text(
        sale ? 'Son satışlar' : 'Son alışlar',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppApi.instance.watch('trades'),
        builder: (context, snap) {
          if (snap.hasError) {
            return DataPanel(child: Text('Fişler okunamadı: ${snap.error}'));
          }
          if (!snap.hasData) return const LinearProgressIndicator();
          final docs =
              snap.data!.docs
                  .where((d) => d.data()['type'] == widget.type)
                  .toList()
                ..sort(
                  (a, b) => (((b.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch) ??
                          0)
                      .compareTo(
                        ((a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch) ??
                            0,
                      ),
                );
          if (docs.isEmpty) {
            return const DataPanel(
              child: BlankState(
                message: 'Henüz işlem yapılmadı.',
                icon: Icons.receipt_long_outlined,
              ),
            );
          }
          return DataPanel(
            child: Column(
              children:
                  docs.take(30).map((d) {
                    final m = d.data();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: green,
                      ),
                      title: Text(
                        '${sale ? 'Satış' : 'Alış'} • ${money(m['totalMinor'] ?? 0)}',
                      ),
                      subtitle: Text(
                        '${m['documentNo'] ?? d.id} • ${dateOf(m['createdAt'])} • ${(m['lines'] as List?)?.length ?? 0} kalem • ${paymentMethodLabel(m['paymentMethod']?.toString())}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showTradeDetails(context, m),
                    );
                  }).toList(),
            ),
          );
        },
      ),
    ],
  );
  Widget _posStep(int number, String title, String subtitle, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: green, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$number. $title',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ink)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _methodChoice(String value, String title, IconData symbol) =>
      ChoiceChip(
        selected: saleMethod == value,
        avatar: Icon(
          symbol,
          size: 18,
          color: saleMethod == value ? green : muted,
        ),
        label: Text(title),
        onSelected: busy || (value == 'credit' && contactId.isEmpty)
            ? null
            : (_) => setState(() => saleMethod = value),
        selectedColor: softGreen,
      );

  Widget _purchaseChoice(String value, String title, IconData symbol) =>
      ChoiceChip(
        selected: purchaseMethod == value,
        avatar: Icon(
          symbol,
          size: 18,
          color: purchaseMethod == value ? green : muted,
        ),
        label: Text(title),
        onSelected: busy || (value == 'credit' && contactId.isEmpty)
            ? null
            : (_) => setState(() => purchaseMethod = value),
        selectedColor: softGreen,
      );

  Widget _totalRow(String title, String value, {bool highlight = false}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: ink,
            fontSize: highlight ? 16 : 14,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 22 : 15,
              fontWeight: FontWeight.w900,
              color: highlight ? green : ink,
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> save() async {
    if (busy || lines.isEmpty) return;
    try {
      final payment =
          sale
              ? salePaidMinor(
                saleMethod,
                total,
                hasContact: contactId.isNotEmpty,
              )
              : (purchaseMethod == 'credit'
                  ? 0
                  : (contactId.isEmpty || paid.text.trim().isEmpty
                      ? total
                      : parseMoney(paid.text)));
      if (payment > total) {
        throw const FormatException('Tahsilat / ödeme toplamdan fazla olamaz.');
      }
      if (!await confirm(
        context,
        sale ? 'Satışı onayla' : 'Alışı onayla',
        '${lines.length} kalem • ${money(total)} • ${sale ? paymentMethodLabel(saleMethod) : 'Alış'}. Stok ve cari kayıtlar güncellenecek.',
      )) {
        return;
      }
      setState(() => busy = true);
      await AppApi.instance.call('commitTrade', {
        'type': widget.type,
        'contactId': contactId.isEmpty ? null : contactId,
        'lines': lines.map((l) => l.json).toList(),
        'paidMinor': payment,
        'paymentMethod': sale ? saleMethod : purchaseMethod,
        'documentKind': documentKind,
        'externalDocumentNo': externalNo.text,
        'projectName': projectName.text,
        'note': note.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        lines.clear();
        paid.clear();
        note.clear();
        externalNo.clear();
        projectName.clear();
        contactId = '';
        saleMethod = 'cash';
        purchaseMethod = 'cash';
        documentKind = 'receipt';
      });
      notify(context, sale ? 'Satış kaydedildi.' : 'Alış kaydedildi.');
      unawaited(ReviewPrompt.instance.recordSuccessfulTrade());
    } catch (e) {
      if (mounted) notify(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

Future<_Line?> _addLineDialog(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> product,
  bool sale,
  bool addVat,
) async {
  final m = product.data();
  final qty = TextEditingController(text: '1');
  final price = TextEditingController(
    text: (((sale ? m['salePriceMinor'] : m['purchasePriceMinor']) ?? 0) / 100)
        .toStringAsFixed(2)
        .replaceAll('.', ','),
  );
  _Line? result;
  await showOwnedDialog<void>(
    context: context,
    controllers: [qty, price],
    builder:
        (dialogContext) => ResponsiveFormDialog(
          title: Text(m['name'] ?? 'Ürün'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mevcut stok: ${quantity(m['stockMilli'] ?? 0)}',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Miktar'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Birim satış/alış fiyatı (₺)',
                    helperText: 'Ürüne girilen fiyat aynen kullanılır.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(sale
                    ? (addVat ? 'KDV ayrıca eklenecek: %${(m['taxRateBps'] ?? 0) / 100}' : 'KDV eklenmeyecek · fiyat değişmez')
                    : 'Alış KDV: %${(m['taxRateBps'] ?? 0) / 100}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final q = parseQty(qty.text);
                  if (q <= 0) {
                    throw const FormatException(
                      'Miktar sıfırdan büyük olmalı.',
                    );
                  }
                  if (sale && q > (m['stockMilli'] ?? 0)) {
                    throw const FormatException('Yetersiz stok.');
                  }
                  result = _Line(
                    product.id,
                    m['name'] ?? '',
                    q,
                    parseMoney(price.text),
                    sale && !addVat ? 0 : (m['taxRateBps'] as num?)?.toInt() ?? 0,
                    (m['taxRateBps'] as num?)?.toInt() ?? 0,
                  );
                  Navigator.pop(dialogContext);
                } catch (e) {
                  notify(context, '$e', error: true);
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
  );
  return result;
}

String tradeSlipText(Map<String, dynamic> trade) {
  final lines = (trade['lines'] as List?) ?? [];
  final total = (trade['totalMinor'] as num?)?.toInt() ?? 0;
  final paid = (trade['paidMinor'] as num?)?.toInt() ?? 0;
  final kind = trade['type'] == 'sale' ? 'SATIŞ FİŞİ' : 'ALIŞ FİŞİ';
  return [
    'STOKPILOT • $kind',
    'Fiş no: ${trade['documentNo'] ?? 'Eski kayıt'}',
    'Tarih: ${dateOf(trade['createdAt'])}',
    'Firma: ${trade['contactName'] ?? 'Peşin işlem'}',
    if ((trade['externalDocumentNo'] ?? '').toString().isNotEmpty)
      'Fatura no: ${trade['externalDocumentNo']}',
    if ((trade['projectName'] ?? '').toString().isNotEmpty)
      'Proje: ${trade['projectName']}',
    '------------------------------',
    for (final raw in lines)
      if (raw is Map)
        '${raw['name'] ?? 'Ürün'} • ${quantity((raw['quantityMilli'] as num?)?.toInt() ?? 0)} × '
            '${money((raw['priceMinor'] as num?)?.toInt() ?? 0)} = '
            '${money((raw['totalMinor'] as num?)?.toInt() ?? 0)}',
    '------------------------------',
    'Ara toplam: ${money((trade['netMinor'] as num?)?.toInt() ?? 0)}',
    'KDV: ${money((trade['taxMinor'] as num?)?.toInt() ?? 0)}',
    'Genel toplam: ${money(total)}',
    'Ödeme: ${paymentMethodLabel(trade['paymentMethod']?.toString())}',
    'Ödenen: ${money(paid)}',
    'Kalan: ${money(total - paid)}',
    if ((trade['note'] ?? '').toString().isNotEmpty) 'Not: ${trade['note']}',
    'Bu belge uygulama işlem kaydıdır; resmî e-Fatura/e-Arşiv değildir.',
  ].join('\n');
}

void showTradeDetails(BuildContext context, Map<String, dynamic> trade) {
  showDialog<void>(
    context: context,
    builder:
        (ctx) => ResponsiveFormDialog(
          title: Text(trade['type'] == 'sale' ? 'Satış fişi' : 'Alış fişi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (trade['documentNo'] ?? 'Eski işlem kaydı').toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateOf(trade['createdAt']),
                style: const TextStyle(color: muted),
              ),
              Text(
                (trade['contactName'] ?? 'Peşin işlem').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if ((trade['externalDocumentNo'] ?? '').toString().isNotEmpty)
                Text('Fatura no: ${trade['externalDocumentNo']}'),
              if ((trade['projectName'] ?? '').toString().isNotEmpty)
                Text('Proje: ${trade['projectName']}'),
              const Divider(height: 24),
              for (final raw in (trade['lines'] as List?) ?? [])
                if (raw is Map)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (raw['name'] ?? 'Ürün').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${quantity((raw['quantityMilli'] as num?)?.toInt() ?? 0)} × '
                          '${money((raw['priceMinor'] as num?)?.toInt() ?? 0)} • '
                          'KDV %${((raw['taxBps'] as num?)?.toInt() ?? 0) / 100}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        Text(money((raw['totalMinor'] as num?)?.toInt() ?? 0)),
                      ],
                    ),
                  ),
              const Divider(),
              Text(
                'Ara toplam: ${money((trade['netMinor'] as num?)?.toInt() ?? 0)}',
              ),
              Text('KDV: ${money((trade['taxMinor'] as num?)?.toInt() ?? 0)}'),
              const SizedBox(height: 5),
              Text(
                'Genel toplam: ${money((trade['totalMinor'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                'Ödeme: ${paymentMethodLabel(trade['paymentMethod']?.toString())}',
              ),
              Text(
                'Ödenen: ${money((trade['paidMinor'] as num?)?.toInt() ?? 0)}',
              ),
              Text(
                'Kalan: ${money(((trade['totalMinor'] as num?)?.toInt() ?? 0) - ((trade['paidMinor'] as num?)?.toInt() ?? 0))}',
              ),
              if ((trade['note'] ?? '').toString().isNotEmpty)
                Text('Not: ${trade['note']}'),
              const SizedBox(height: 12),
              const Text(
                'Bu fiş uygulama işlem kaydıdır; resmî e-Fatura/e-Arşiv değildir.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: tradeSlipText(trade)),
                );
                if (ctx.mounted) notify(ctx, 'Fiş panoya kopyalandı.');
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Fişi kopyala'),
            ),
          ],
        ),
  );
}

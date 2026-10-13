import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/sales_tools.dart';
import '../core/smart_inventory.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

/// A full-screen, keyboard-safe form route. Avoids nested AlertDialog
/// intrinsic measurement and inherited-widget teardown during modal pop.
class ProductFormScaffold extends StatelessWidget {
  const ProductFormScaffold({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: title),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: content,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProductOption {
  const ProductOption(this.id, this.name, {this.taxRateBps = 0});
  final String id;
  final String name;
  final int taxRateBps;
}

class ProductCatalog {
  const ProductCatalog({
    this.categories = const [],
    this.units = const [],
    this.taxes = const [],
    this.products = const [],
  });
  final List<ProductOption> categories;
  final List<ProductOption> units;
  final List<ProductOption> taxes;
  final List<MapEntry<String, Map<String, dynamic>>> products;

  static Future<ProductCatalog> fetch() async {
    final api = AppApi.instance;
    final cats = await api.collection('categories').get();
    final units = await api.collection('units').get();
    final taxes = await api.collection('taxRates').get();
    final products = await api.collection('products').get();
    return ProductCatalog(
      categories:
          cats.docs
              .map(
                (d) => ProductOption(d.id, (d.data()['name'] ?? '').toString()),
              )
              .toList(),
      units:
          units.docs
              .map(
                (d) => ProductOption(d.id, (d.data()['name'] ?? '').toString()),
              )
              .toList(),
      taxes:
          taxes.docs
              .map(
                (d) => ProductOption(
                  d.id,
                  (d.data()['name'] ?? '').toString(),
                  taxRateBps: (d.data()['rateBps'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList(),
      products: products.docs.map((d) => MapEntry(d.id, d.data())).toList(),
    );
  }
}

/// A real route with its own lifecycle: controllers are not disposed until
/// after the closing animation completes and the widget is unmounted.
class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({
    super.key,
    required this.loadCatalog,
    required this.saveProduct,
    this.existing,
    this.existingId,
  });

  final Future<ProductCatalog> Function() loadCatalog;
  final Future<void> Function(Map<String, dynamic>) saveProduct;
  final Map<String, dynamic>? existing;
  final String? existingId;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController sku;
  late final TextEditingController barcode;
  late final TextEditingController purchase;
  late final TextEditingController sale;
  late final TextEditingController minimum;
  late Future<ProductCatalog> _catalog;

  late String categoryId;
  late String unitId;
  late int taxRateBps;
  bool active = true;
  bool pricesIncludeVat = false;
  bool saving = false;
  String? error;

  String _currency(dynamic amount) => ((amount is num ? amount : 0) / 100)
      .toStringAsFixed(2)
      .replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    final data = widget.existing ?? const <String, dynamic>{};
    name = TextEditingController(text: (data['name'] ?? '').toString());
    sku = TextEditingController(text: (data['sku'] ?? '').toString());
    barcode = TextEditingController(text: (data['barcode'] ?? '').toString());
    purchase = TextEditingController(
      text: _currency(data['purchasePriceMinor']),
    );
    sale = TextEditingController(text: _currency(data['salePriceMinor']));
    minimum = TextEditingController(
      text: quantity((data['minStockMilli'] as num?)?.toInt() ?? 0),
    );
    categoryId = (data['categoryId'] ?? '').toString();
    unitId = (data['unitId'] ?? '').toString();
    active = data['isActive'] != false;
    taxRateBps = (data['taxRateBps'] as num?)?.toInt() ?? 0;
    purchase.addListener(_updatePricing);
    sale.addListener(_updatePricing);
    name.addListener(_updatePricing);
    sku.addListener(_updatePricing);
    barcode.addListener(_updatePricing);
    _catalog = widget.loadCatalog();
  }

  void _updatePricing() {
    if (mounted && !saving) setState(() {});
  }

  int _enteredNetPrice(String text) {
    final amount = parseMoney(text);
    return pricesIncludeVat
        ? netFromGrossMinor(amount, taxRateBps)
        : amount;
  }

  int? _tryPrice(String text) {
    try {
      return _enteredNetPrice(text);
    } catch (_) {
      return null;
    }
  }

  void _setPriceIncludesVat(bool include) {
    if (pricesIncludeVat == include) return;
    for (final field in [purchase, sale]) {
      final entered = _tryPrice(field.text);
      if (entered == null) continue;
      final displayAmount = include
          ? grossMinor(entered, taxRateBps)
          : entered;
      field.text = (displayAmount / 100)
          .toStringAsFixed(2).replaceAll('.', ',');
    }
    setState(() => pricesIncludeVat = include);
  }

  @override
  void dispose() {
    purchase.removeListener(_updatePricing);
    sale.removeListener(_updatePricing);
    name.removeListener(_updatePricing);
    sku.removeListener(_updatePricing);
    barcode.removeListener(_updatePricing);
    for (final input in [name, sku, barcode, purchase, sale, minimum]) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _save(ProductCatalog options) async {
    if (saving) return;
    try {
      if (name.text.trim().isEmpty) {
        throw const FormatException('Ürün adı zorunludur.');
      }
      final match = _match(options);
      if (match != null) {
        throw FormatException(
          'Bu ürün zaten kayıtlı: ${match.name}. Mevcut kaydı düzenleyin.',
        );
      }
      final values = <String, dynamic>{
        'name': name.text.trim(),
        'sku': sku.text.trim(),
        'barcode': barcode.text.trim(),
        'categoryId': categoryId,
        'unitId': unitId,
        'taxRateBps': taxRateBps,
        'purchasePriceMinor': _enteredNetPrice(purchase.text),
        'salePriceMinor': _enteredNetPrice(sale.text),
        'minStockMilli': parseQty(minimum.text),
        'isActive': active,
      };
      setState(() {
        saving = true;
        error = null;
      });
      await widget.saveProduct(values);
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = exception.toString().replaceFirst('FormatException: ', '');
        });
      }
    }
  }

  ProductMatch? _match(ProductCatalog options) => findProductMatch(
    name: name.text,
    sku: sku.text,
    barcode: barcode.text,
    products: options.products,
    excludingId: widget.existingId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<ProductCatalog>(
    future: _catalog,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ProductFormScaffold(
          title: const Text('Ürün seçenekleri yüklenemedi'),
          content: Text(snapshot.error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
            FilledButton(
              onPressed:
                  () => setState(() {
                    _catalog = widget.loadCatalog();
                  }),
              child: const Text('Tekrar dene'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const ProductFormScaffold(
          title: Text('Ürün bilgileri yükleniyor'),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      final options = snapshot.data!;
      final duplicate = _match(options);
      final categoryValue =
          options.categories.any((o) => o.id == categoryId) ? categoryId : '';
      final unitValue = options.units.any((o) => o.id == unitId) ? unitId : '';
      final vatRates =
          <int>{
              0,
              100,
              1000,
              2000,
              taxRateBps,
              ...options.taxes.map((item) => item.taxRateBps),
            }.toList()
            ..sort();
      final purchaseNet = _tryPrice(purchase.text);
      final saleNet = _tryPrice(sale.text);
      final markup =
          purchaseNet == null || saleNet == null
              ? null
              : profitMarkupPercent(purchaseNet, saleNet);
      return ProductFormScaffold(
        title: Text(widget.existing == null ? 'Yeni ürün' : 'Ürün düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Ürün adı *'),
            ),
            if (duplicate != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('duplicate-product-warning'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '“${duplicate.name}” zaten kayıtlı. Mevcut ürünü düzenleyin.',
                  style: const TextStyle(
                    color: Color(0xFF80500C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ResponsiveFields(
              first: TextField(
                controller: sku,
                decoration: const InputDecoration(labelText: 'Stok kodu (SKU)'),
              ),
              second: TextField(
                controller: barcode,
                decoration: InputDecoration(
                  labelText: 'Barkod',
                  suffixIcon: IconButton(
                    tooltip: 'Otomatik iç barkod üret',
                    icon: const Icon(Icons.auto_awesome_rounded),
                    onPressed:
                        saving
                            ? null
                            : () {
                              barcode.text = generateInternalBarcode();
                              setState(() {});
                            },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Otomatik 20 ile başlayan barkodlar yalnızca iç kullanım içindir; GS1 kodu değildir.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('category-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Seçiniz')),
                ...options.categories.map(
                  (o) => DropdownMenuItem(
                    value: o.id,
                    child: Text(
                      o.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
              onChanged:
                  saving ? null : (v) => setState(() => categoryId = v ?? ''),
            ),
            const SizedBox(height: 12),
            ResponsiveFields(
              first: DropdownButtonFormField<String>(
                key: ValueKey('unit-$unitValue'),
                initialValue: unitValue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Birim'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Seçiniz')),
                  ...options.units.map(
                    (o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(
                        o.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                onChanged:
                    saving ? null : (v) => setState(() => unitId = v ?? ''),
              ),
              second: DropdownButtonFormField<int>(
                key: ValueKey('vat-$taxRateBps'),
                initialValue: taxRateBps,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'KDV oranı'),
                items:
                    vatRates
                        .map(
                          (rate) => DropdownMenuItem(
                            value: rate,
                            child: Text(
                              '%' +
                                  (rate / 100).toStringAsFixed(
                                    rate % 100 == 0 ? 0 : 2,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged:
                    saving
                        ? null
                        : (rate) => setState(() => taxRateBps = rate ?? 0),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD6ECE4))),
              child: SwitchListTile.adaptive(
                key: const ValueKey('vat-inclusive-input'),
                title: const Text('Fiyatları KDV dâhil gir',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
                subtitle: const Text('Değiştirince girilmiş tutarlar dönüştürülür; kayıtlarda net fiyat saklanır.',
                  style: TextStyle(color: muted, fontSize: 11)),
                value: pricesIncludeVat,
                onChanged: saving ? null : _setPriceIncludesVat,
              )),
            const SizedBox(height: 12),
            ResponsiveFields(
              first: TextField(
                controller: purchase,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: pricesIncludeVat
                    ? 'KDV dâhil alış (₺)'
                    : 'KDV hariç alış (₺)',
                ),
              ),
              second: TextField(
                controller: sale,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: pricesIncludeVat
                    ? 'KDV dâhil satış (₺)'
                    : 'KDV hariç satış (₺)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('pricing-preview'),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBEBDF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ANLIK FİYAT ANALİZİ',
                    style: TextStyle(
                      fontSize: 11,
                      color: muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _previewFigure(
                        'KDV dâhil alış',
                        purchaseNet == null
                            ? '—'
                            : money(grossMinor(purchaseNet, taxRateBps)),
                      ),
                      _previewFigure(
                        'KDV dâhil satış',
                        saleNet == null
                            ? '—'
                            : money(grossMinor(saleNet, taxRateBps)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: markup ?? 0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder:
                        (context, value, child) => Row(
                          children: [
                            Icon(
                              value >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: value >= 0 ? green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                markup == null
                                    ? 'Kâr için alış fiyatı girin'
                                    : 'Tahmini kâr (maliyet üzerinden): %' +
                                        value.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: value >= 0 ? green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tahmini kâr KDV hariç alış/satış fiyatından hesaplanır; giderler hariçtir.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minimum,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Kritik stok eşiği'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ürün aktif'),
              value: active,
              onChanged: saving ? null : (v) => setState(() => active = v),
            ),
            const Text(
              'İlk stoku ürünü kaydettikten sonra Stok işlemi üzerinden ekleyin.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFB73232),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed:
                saving || duplicate != null ? null : () => _save(options),
            child: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ],
      );
    },
  );
  Widget _previewFigure(String title, String price) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: muted, fontSize: 12)),
      Text(
        price,
        style: const TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// Stable stock dialog. A previous implementation disposed controllers while
/// the Navigator was still animating the old route out of the element tree.
class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({
    super.key,
    required this.productName,
    required this.adjustStock,
  });

  final String productName;
  final Future<void> Function(int deltaMilli, String note) adjustStock;

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final amount = TextEditingController();
  final note = TextEditingController();
  bool adding = true;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    try {
      final value = parseQty(amount.text);
      if (value <= 0) {
        throw const FormatException('Miktar sıfırdan büyük olmalıdır.');
      }
      setState(() {
        saving = true;
        error = null;
      });
      await widget.adjustStock(adding ? value : -value, note.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = exception.toString().replaceFirst('FormatException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ProductFormScaffold(
    title: Text('${widget.productName} • Stok işlemi'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Stok giriş')),
            ButtonSegment(value: false, label: Text('Stok çıkış')),
          ],
          selected: {adding},
          onSelectionChanged:
              saving ? null : (value) => setState(() => adding = value.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Miktar (ör: 2,5)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Açıklama'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB73232))),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Kaydediliyor...' : 'Kaydet'),
      ),
    ],
  );
}

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';
import '../services/billing.dart';
import '../widgets/ui.dart';
import 'legal_page.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});
  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool loading = false;
  late Future<List<ProductDetails>> offerings = BillingService.instance.products();
  Future<void> run(Future<void> Function() action) async {
    setState(() => loading = true);
    try {
      await action();
      if (mounted) {
        notify(context, 'İşlem mağazaya iletildi. Doğrulama tamamlandığında Pro açılır.');
      }
    } catch (e) {
      if (mounted) notify(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pro abonelik')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: green,
                size: 65,
              ),
              const SizedBox(height: 12),
              const Text(
                'StokPilot Pro',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'İlk 50 ürün ücretsiz. İşletmeniz büyüdüğünde aylık Pro aboneliğiyle sınırsız ürün ekleyin. Mevcut kayıtlarınıza erişmeye devam edebilirsiniz.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              const DataPanel(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.inventory_2_outlined, color: green),
                      title: Text('Sınırsız ürün'),
                      subtitle: Text(
                        '50 üründen sonra da büyümeye devam edin.',
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.cloud_done_outlined, color: green),
                      title: Text('Aynı çalışma alanı'),
                      subtitle: Text(
                        'Ürünleriniz ve işlem geçmişiniz korunur.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!BillingService.instance.canPurchase)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Ödeme doğrulama sistemi etkinleştirildikten sonra aylık abonelik satın alınabilir. Mevcut ürünlerinizi yönetmeye devam edebilirsiniz.',
                    textAlign: TextAlign.center,
                  ),
                ),
              FutureBuilder(
                future: offerings,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Column(
                      children: [
                        const Text(
                          'Mağazaya bağlanılamadı. Lütfen tekrar deneyin.',
                        ),
                        TextButton(
                          onPressed:
                              () => setState(
                                () =>
                                    offerings =
                                        BillingService.instance.products(),
                              ),
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    );
                  }
                  final packages = snap.data ?? <ProductDetails>[];
                  if (snap.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  return Column(
                    children: [
                      if (packages.isEmpty && BillingService.instance.canPurchase)
                        const Text(
                          'Aylık abonelik şu anda alınamıyor. Lütfen daha sonra tekrar deneyin.',
                          textAlign: TextAlign.center,
                        ),
                      ...packages.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  loading || !BillingService.instance.canPurchase
                                      ? null
                                      : () => run(
                                        () =>
                                            BillingService.instance.purchase(p),
                                      ),
                              child: Text(
                                'Abone ol • ${p.price} / ay',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              ValueListenableBuilder<String?>(
                valueListenable: BillingService.instance.lastError,
                builder: (context, message, _) => message == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Aylık abonelik otomatik yenilenir. Ücret ve yenileme koşulları ödeme öncesi mağazada gösterilir. Aboneliğinizi mağaza hesabınızdan iptal edebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              TextButton(
                onPressed:
                    loading || !BillingService.instance.canPurchase
                        ? null
                        : () => run(BillingService.instance.restore),
                child: const Text('Satın alımları geri yükle'),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalPage(privacy: true),
                          ),
                        ),
                    child: const Text('Gizlilik'),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalPage(privacy: false),
                          ),
                        ),
                    child: const Text('Koşullar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

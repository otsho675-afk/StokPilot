import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<void> run(Future<void> Function() action) async {
    setState(() => loading = true);
    try {
      await action();
      if (mounted) {
        notify(context, 'İşlem tamamlandı. Abonelik onayı bekleniyor.');
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
                'İlk 50 ürününüz ücretsiz. Sınırsız ürün eklemek için StokPilot Pro aylık aboneliğine geçin. Türkiye hedef fiyatı 50 TL/aydır; ödeme öncesinde mağazadaki kesin fiyatı kontrol edin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              if (!BillingService.verifiedBackendReady)
                const Text(
                  'Test sürümü: güvenli mağaza doğrulaması henüz kurulmadı; ödeme alınmaz. İlk 50 ürün ücretsizdir.',
                  textAlign: TextAlign.center,
                ),
              if (!BillingService.instance.available)
                const Text(
                  'Mağaza abonelik anahtarları henüz yapılandırılmamış. Kurulum rehberini uygulayın.',
                  textAlign: TextAlign.center,
                ),
              FutureBuilder(
                future: BillingService.instance.packages(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text(
                      'Mağaza ürünleri yüklenemedi: ${snap.error}',
                      textAlign: TextAlign.center,
                    );
                  }
                  final packages =
                      (snap.data ?? [])
                          .where((p) => p.packageType == PackageType.monthly)
                          .toList();
                  if (snap.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  return Column(
                    children: [
                      if (packages.isEmpty)
                        const Text(
                          'Aylık abonelik ürünü bulunamadı. Google Play / App Store ve RevenueCat ürün eşleştirmelerini kontrol edin.',
                          textAlign: TextAlign.center,
                        ),
                      ...packages.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  loading ||
                                          !BillingService.verifiedBackendReady
                                      ? null
                                      : () => run(
                                        () =>
                                            BillingService.instance.purchase(p),
                                      ),
                              child: Text(
                                'Abone ol • ${p.storeProduct.priceString} / ay',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 7),
              const Text(
                'Aylık abonelik otomatik yenilenir. Ücret ve yenileme koşulları ödeme öncesi mağazada gösterilir. Aboneliğinizi mağaza hesabınızdan iptal edebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              TextButton(
                onPressed:
                    loading ? null : () => run(BillingService.instance.restore),
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
                  TextButton(
                    onPressed: () => requestAccountDeletion(context),
                    child: const Text('Hesabı sil'),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await BillingService.instance.logout();
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Başka hesapla giriş yap'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Uses the official Apple/Google stores. Never grants Pro locally:
/// Firestore is updated only after the store receipt is verified server-side.
class BillingService {
  BillingService._();
  static final instance = BillingService._();

  static const productId = 'stokpilot_pro_monthly';
  static const workerUrl = String.fromEnvironment('STORE_BILLING_ENDPOINT');
  // Keep disabled until the Worker, store credentials and sandbox tests are ready.
  static const verifiedBackendReady = bool.fromEnvironment(
    'STORE_BILLING_READY',
    defaultValue: false,
  );

  final InAppPurchase _store = InAppPurchase.instance;
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _storeReady = false;
  String? _uid;

  bool get available =>
      !kIsWeb &&
      (Platform.isIOS || Platform.isAndroid) &&
      _storeReady &&
      workerUrl.startsWith('https://') &&
      verifiedBackendReady;

  Future<void> identify(String uid) async {
    _uid = uid;
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    _subscription ??= _store.purchaseStream.listen(
      (events) => unawaited(_handlePurchases(events)),
      onError: (Object error) {
        message.value = 'Mağaza işlemi tamamlanamadı. Lütfen tekrar deneyin.';
      },
    );
    try {
      _storeReady = await _store.isAvailable();
    } catch (_) {
      _storeReady = false;
    }
  }

  Future<List<ProductDetails>> packages() async {
    if (!available) return [];
    final response = await _store.queryProductDetails({productId});
    if (response.error != null) {
      throw StateError('Abonelik mağazadan alınamadı: ${response.error!.message}');
    }
    return response.productDetails.where((p) => p.id == productId).toList();
  }

  Future<void> purchase(ProductDetails product) async {
    if (!available || product.id != productId) {
      throw StateError('Güvenli abonelik doğrulaması henüz kullanıma hazır değil.');
    }
    message.value = 'Mağazanın ödeme ekranı açılıyor…';
    // The plugin uses buyNonConsumable for auto-renewing subscriptions.
    await _store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore() async {
    if (!available) {
      throw StateError('Abonelik doğrulama hizmeti henüz hazır değil.');
    }
    message.value = 'Satın alımlar kontrol ediliyor…';
    await _store.restorePurchases();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> events) async {
    for (final purchase in events) {
      if (purchase.productID != productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          message.value = 'Ödeme mağaza tarafından işleniyor…';
          break;
        case PurchaseStatus.error:
          message.value = purchase.error?.message ?? 'Ödeme tamamlanamadı.';
          break;
        case PurchaseStatus.canceled:
          message.value = 'Ödeme iptal edildi.';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            if (!available) {
              throw StateError('Doğrulama sunucusu yapılandırılmamış.');
            }
            final proof = Platform.isAndroid
                ? purchase.verificationData.serverVerificationData
                : purchase.purchaseID ?? '';
            if (proof.isEmpty) {
              throw StateError('Mağazadan satın alma belgesi alınamadı.');
            }
            await _verifyWithServer(proof);
            message.value = 'Abonelik doğrulandı. Pro erişiminiz güncellendi.';
            if (purchase.pendingCompletePurchase) {
              await _store.completePurchase(purchase);
            }
          } catch (_) {
            // Do not grant Pro or acknowledge an unverified purchase.
            message.value =
                'Ödeme mağazada görünüyor ancak doğrulanamadı. '
                'Lütfen bağlantınızı kontrol edip Satın alımları geri yükle seçeneğini deneyin.';
          }
          break;
      }
    }
  }

  Future<void> _verifyWithServer(String proof) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _uid) {
      throw StateError('Aktif bir kullanıcı oturumu gerekli.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) throw StateError('Oturum doğrulanamadı.');
    final uri = Uri.parse(workerUrl).resolve('/verify');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.write(jsonEncode({
        'platform': Platform.isIOS ? 'ios' : 'android',
        'proof': proof,
        'productId': productId,
      }));
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200 ||
          (jsonDecode(body) as Map<String, dynamic>)['active'] != true) {
        throw StateError('Mağaza doğrulaması başarılı olmadı.');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> logout() async {
    _uid = null;
    message.value = null;
  }
}

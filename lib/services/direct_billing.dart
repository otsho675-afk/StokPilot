import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

/// Native StoreKit / Google Play Billing; purchase proof is verified server-side.
class BillingService {
  BillingService._();
  static final instance = BillingService._();
  static const productId = 'stokpilot_pro_monthly';
  static const bool verifiedBackendReady = bool.fromEnvironment(
    'DIRECT_BILLING_READY',
    defaultValue: false,
  );
  static const endpoint = String.fromEnvironment(
    'DIRECT_BILLING_URL',
    defaultValue: 'https://stokpilot-billing.otsho675.workers.dev',
  );

  final ValueNotifier<String?> lastError = ValueNotifier(null);
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String? _uid;
  bool _processing = false;

  bool get available => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get canPurchase => available && verifiedBackendReady;

  Future<void> identify(String uid) async {
    _uid = uid;
    if (!canPurchase || _subscription != null) return;
    // Listen *before* querying products to process resumed unfinished purchases.
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      (updates) => unawaited(_onPurchases(updates)),
      onError: (Object error) => lastError.value = 'Mağaza bağlantı hatası: $error',
    );
  }

  Future<List<ProductDetails>> products() async {
    if (!canPurchase || !await InAppPurchase.instance.isAvailable()) return [];
    final response = await InAppPurchase.instance.queryProductDetails({productId});
    if (response.error != null) throw StateError(response.error!.message);
    if (response.notFoundIDs.contains(productId)) {
      throw StateError('Mağazada StokPilot Pro aboneliği henüz bulunamadı.');
    }
    return response.productDetails.where((p) => p.id == productId).toList();
  }

  Future<void> purchase(ProductDetails product) async {
    if (!canPurchase || product.id != productId) {
      throw StateError('Satın alma henüz etkin değil.');
    }
    final success = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!success) throw StateError('Mağaza ödeme ekranı açılamadı.');
    // Completion is performed *only* after the Worker validates the receipt.
  }

  Future<void> restore() async {
    if (!canPurchase) throw StateError('Satın almaları geri yükleme henüz hazır değil.');
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    if (_processing) return;
    _processing = true;
    try {
      for (final purchase in purchases) {
        if (purchase.productID != productId) continue;
        if (purchase.status == PurchaseStatus.pending) continue;
        if (purchase.status == PurchaseStatus.error) {
          lastError.value = purchase.error?.message ?? 'Satın alma başarısız.';
          continue;
        }
        if (purchase.status == PurchaseStatus.canceled) continue;
        if (purchase.status != PurchaseStatus.purchased &&
            purchase.status != PurchaseStatus.restored) continue;
        try {
          await _verify(purchase);
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          lastError.value = null;
        } catch (error) {
          // Never acknowledge/deliver an unverified purchase as Pro.
          lastError.value = 'Ödeme doğrulanamadı: $error';
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _uid) {
      throw StateError('Satın alınan üyeliği doğrulamak için hesabınıza giriş yapın.');
    }
    final token = await user.getIdToken(true);
    if (token == null) throw StateError('Güvenli oturum anahtarı bulunamadı.');
    final isApple = Platform.isIOS;
    final proof = isApple
        ? (purchase.purchaseID ?? '')
        : purchase.verificationData.serverVerificationData;
    if (proof.isEmpty) throw StateError('Mağaza doğrulama bilgisi alınamadı.');
    final response = await http.post(
      Uri.parse('${endpoint.replaceAll(RegExp(r"/+$"), "")}/verify'),
      headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
      body: jsonEncode({
        'platform': isApple ? 'ios' : 'android',
        'productId': productId,
        isApple ? 'transactionId' : 'purchaseToken': proof,
      }),
    ).timeout(const Duration(seconds: 25));
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('Doğrulama servisi geçersiz cevap verdi.');
    }
    if (response.statusCode != 200) {
      throw StateError((body['error'] ?? 'HTTP ${response.statusCode}').toString());
    }
    // The Firestore entitlement is written by the Worker only, not by the app.
  }

  Future<void> logout() async {
    _uid = null;
    lastError.value = null;
  }
}

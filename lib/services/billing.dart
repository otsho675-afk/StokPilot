import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class BillingService {
  BillingService._();
  static final instance = BillingService._();
  static const androidKey = String.fromEnvironment('RC_ANDROID_PUBLIC_KEY');
  static const iosKey = String.fromEnvironment('RC_IOS_PUBLIC_KEY');
  static const bool verifiedBackendReady = bool.fromEnvironment('RC_VERIFIED_BACKEND_READY', defaultValue: false);
  bool _configured = false;
  bool get available => !kIsWeb && ((Platform.isAndroid && androidKey.isNotEmpty) || (Platform.isIOS && iosKey.isNotEmpty));

  Future<void> identify(String uid) async {
    if (!available) return;
    if (!_configured) {
      final config = PurchasesConfiguration(Platform.isAndroid ? androidKey : iosKey)..appUserID = uid;
      await Purchases.configure(config);
      _configured = true;
    } else {
      await Purchases.logIn(uid);
    }
  }
  Future<List<Package>> packages() async {
    if (!available) return [];
    final offering = (await Purchases.getOfferings()).current;
    return offering?.availablePackages ?? [];
  }
  Future<void> purchase(Package package) async {
    if (!verifiedBackendReady) throw StateError('Güvenli ödeme doğrulaması kurulmadığı için satın alma kapalı.');
    // Local callback does NOT grant access. RevenueCat webhook updates Firestore.
    await Purchases.purchase(PurchaseParams.package(package));
  }
  Future<void> restore() async { if (available) await Purchases.restorePurchases(); }
  Future<void> logout() async { if (_configured) await Purchases.logOut(); }
}

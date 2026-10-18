import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/services/app_api.dart';

void main() {
  test('product quota uses the active direct store entitlement', () {
    AppApi.useTestBackend(
      MockFirebaseAuth(
        mockUser: MockUser(uid: 'store-customer'),
        signedIn: true,
      ),
      FakeFirebaseFirestore(),
    );
    addTearDown(AppApi.resetTestBackend);

    final api = AppApi.instance;
    final future = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );
    final past = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      api.hasPro({
        'status': 'active',
        'source': 'direct-store',
        'expiresAt': future,
      }),
      isTrue,
    );
    expect(
      api.hasPro({
        'status': 'expired',
        'source': 'direct-store',
        'expiresAt': future,
      }),
      isFalse,
    );
    expect(
      api.hasPro({
        'status': 'active',
        'source': 'direct-store',
        'expiresAt': past,
      }),
      isFalse,
    );
    expect(
      api.hasPro({
        'status': 'active',
        'source': 'revenuecat',
        'expiresAt': future,
      }),
      isFalse,
    );
  });
}

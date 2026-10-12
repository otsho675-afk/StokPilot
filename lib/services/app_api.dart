import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Spark backend. Secure quota is enforced in Firestore rules.
class AppApi {
  AppApi._();
  static final instance = AppApi._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String get uid => auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get workspace =>
      firestore.collection('workspaces').doc(uid);
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      workspace.collection(name);
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String name) =>
      collection(name).snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> entitlement() =>
      collection('entitlements').doc('current').snapshots();

  Future<void> initialize() async {
    final ref = workspace;
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'ownerUid': uid,
          'name': 'İşletmem',
          'currency': 'TRY',
          'productCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  bool _hasPro(Map<String, dynamic>? ent) {
    final expiry = ent?['expiresAt'];
    return ent?['status'] == 'active' &&
        ent?['source'] == 'revenuecat' &&
        expiry is Timestamp &&
        expiry.toDate().isAfter(DateTime.now());
  }

  Future<void> create(String name, Map<String, dynamic> data) async {
    if (name == 'products') return _createProduct(data);
    if (!const ['categories', 'units', 'taxRates', 'contacts'].contains(name)) {
      throw StateError('Bu koleksiyona kayıt eklenemez.');
    }
    await collection(name).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> edit(String name, String id, Map<String, dynamic> data) async {
    if (!const ['products', 'categories', 'units', 'taxRates', 'contacts']
        .contains(name)) {
      throw StateError('Bu koleksiyon düzenlenemez.');
    }
    await collection(name).doc(id).update(data);
  }

  Future<void> _createProduct(Map<String, dynamic> data) async {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isEmpty) throw const FormatException('Ürün adı gerekli.');
    final productRef = collection('products').doc();
    final ws = workspace;
    final entitlementRef = collection('entitlements').doc('current');
    await firestore.runTransaction((tx) async {
      // All transaction reads must be completed before the first write.
      final snapshot = await tx.get(ws);
      final entitlement = await tx.get(entitlementRef);
      if (!snapshot.exists) throw StateError('İşletme henüz oluşturulmamış.');
      final count = (snapshot.data()?['productCount'] as num?)?.toInt() ?? 0;
      if (!_hasPro(entitlement.data()) && count >= 50) {
        throw StateError('Ücretsiz 50 ürün hakkı doldu.');
      }
      tx.set(productRef, {
        'name': name,
        'sku': (data['sku'] ?? '').toString().trim(),
        'barcode': (data['barcode'] ?? '').toString().trim(),
        'categoryId': (data['categoryId'] ?? '').toString(),
        'unitId': (data['unitId'] ?? '').toString(),
        'taxRateBps': data['taxRateBps'] ?? 0,
        'purchasePriceMinor': data['purchasePriceMinor'] ?? 0,
        'salePriceMinor': data['salePriceMinor'] ?? 0,
        'minStockMilli': data['minStockMilli'] ?? 0,
        'isActive': data['isActive'] ?? true,
        'stockMilli': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // A transaction may add exactly ONE product with each counter increment.
      tx.update(ws, {'productCount': count + 1, 'lastProductId': productRef.id});
    });
  }

  int _int(dynamic value, {int min = 0, int max = 1000000000000}) {
    if (value is! int || value < min || value > max) {
      throw const FormatException('Geçersiz sayısal değer.');
    }
    return value;
  }

  Future<dynamic> call(String method, Map<String, dynamic> data) {
    switch (method) {
      case 'createProduct':
        return _createProduct(data);
      case 'adjustStock':
        return _adjustStock(data);
      case 'commitTrade':
        return _commitTrade(data);
      case 'postPayment':
        return _postPayment(data);
      case 'deleteAccount':
        return deleteAccount();
      default:
        throw StateError('Bilinmeyen işlem: $method');
    }
  }

  Future<void> _adjustStock(Map<String, dynamic> data) async {
    final id = data['productId']?.toString() ?? '';
    final delta = _int(data['deltaMilli'], min: -1000000000000);
    if (id.isEmpty || delta == 0) {
      throw const FormatException('Stok hareketi geçersiz.');
    }
    final productRef = collection('products').doc(id);
    final moveRef = collection('stockMoves').doc();
    await firestore.runTransaction((tx) async {
      final product = await tx.get(productRef);
      if (!product.exists) throw StateError('Ürün bulunamadı.');
      final old = (product.data()?['stockMilli'] as num?)?.toInt() ?? 0;
      final next = old + delta;
      if (next < 0 || next > 1000000000000) {
        throw StateError('Stok eksiye düşemez veya üst sınıra çıkamaz.');
      }
      tx.update(productRef, {'stockMilli': next});
      tx.set(moveRef, {
        'productId': id,
        'tradeId': null,
        'deltaMilli': delta,
        'reason': 'adjustment',
        'note': (data['note'] ?? '').toString().trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Map<String, dynamic>> _commitTrade(Map<String, dynamic> data) async {
    final type = data['type'];
    final raw = data['lines'];
    if ((type != 'sale' && type != 'purchase') ||
        raw is! List || raw.isEmpty || raw.length > 30) {
      throw const FormatException('İşlem geçersiz. En çok 30 ürün seçin.');
    }
    final lines = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final ids = lines.map((item) => item['productId']?.toString() ?? '').toList();
    if (ids.any((id) => id.isEmpty) || ids.toSet().length != ids.length) {
      throw const FormatException('Her ürün bir kez seçilmelidir.');
    }
    final contactId = data['contactId']?.toString() ?? '';
    final paid = _int(data['paidMinor'] ?? 0);
    final contactRef = contactId.isEmpty ? null : collection('contacts').doc(contactId);
    final productRefs = ids.map((id) => collection('products').doc(id)).toList();
    final tradeRef = collection('trades').doc();
    final moveRefs = ids.map((_) => collection('stockMoves').doc()).toList();

    return firestore.runTransaction((tx) async {
      final contact = contactRef == null ? null : await tx.get(contactRef);
      final products = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in productRefs) {
        products.add(await tx.get(ref));
      }
      if (contactRef != null && (contact == null || !contact.exists)) {
        throw StateError('Cari bulunamadı.');
      }
      var netTotal = 0, taxTotal = 0, grossTotal = 0;
      final recordedLines = <Map<String, dynamic>>[];
      final nextStocks = <int>[];
      for (var i = 0; i < lines.length; i++) {
        final product = products[i].data();
        if (product == null || product['isActive'] == false) {
          throw StateError('Ürün bulunamadı veya pasif.');
        }
        final qty = _int(lines[i]['quantityMilli'], min: 1);
        final price = _int(lines[i]['priceMinor']);
        final vatBps = _int(product['taxRateBps'] ?? 0, max: 10000);
        final oldStock = _int(product['stockMilli'] ?? 0);
        final nextStock = type == 'sale' ? oldStock - qty : oldStock + qty;
        if (nextStock < 0 || nextStock > 1000000000000) {
          throw StateError('Stok miktarı yetersiz: ${product['name']}');
        }
        final net = (qty * price / 1000).round();
        final tax = (net * vatBps / 10000).round();
        final gross = net + tax;
        if (gross > 1000000000000) {
          throw const FormatException('İşlem limiti aşıldı.');
        }
        netTotal += net;
        taxTotal += tax;
        grossTotal += gross;
        nextStocks.add(nextStock);
        recordedLines.add({
          'productId': ids[i],
          'name': product['name'],
          'quantityMilli': qty,
          'priceMinor': price,
          'taxBps': vatBps,
          'netMinor': net,
          'taxMinor': tax,
          'totalMinor': gross,
        });
      }
      if (grossTotal > 1000000000000 || paid > grossTotal) {
        throw const FormatException('Ödenen tutar geçersiz.');
      }
      if (contactRef == null && paid != grossTotal) {
        throw const FormatException('Veresiye işlem için cari seçmelisiniz.');
      }
      for (var i = 0; i < recordedLines.length; i++) {
        tx.update(productRefs[i], {'stockMilli': nextStocks[i]});
        tx.set(moveRefs[i], {
          'productId': ids[i],
          'tradeId': tradeRef.id,
          'deltaMilli': type == 'sale' ? -(recordedLines[i]['quantityMilli'] as int) : recordedLines[i]['quantityMilli'],
          'reason': type,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (contactRef != null) {
        final oldBalance = (contact!.data()?['balanceMinor'] as num?)?.toInt() ?? 0;
        final newBalance = oldBalance + (grossTotal - paid) * (type == 'sale' ? 1 : -1);
        if (newBalance.abs() > 1000000000000) {
          throw const FormatException('Cari bakiye üst sınırı aşıldı.');
        }
        tx.update(contactRef, {'balanceMinor': newBalance});
      }
      tx.set(tradeRef, {
        'type': type,
        'contactId': contactRef?.id,
        'lines': recordedLines,
        'paidMinor': paid,
        'netMinor': netTotal,
        'taxMinor': taxTotal,
        'totalMinor': grossTotal,
        'note': (data['note'] ?? '').toString().trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (paid > 0) {
        tx.set(collection('payments').doc(), {
          'contactId': contactRef?.id,
          'tradeId': tradeRef.id,
          'type': type == 'sale' ? 'collection' : 'payout',
          'amountMinor': paid,
          'auto': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return {'id': tradeRef.id};
    });
  }

  Future<Map<String, dynamic>> _postPayment(Map<String, dynamic> data) async {
    final id = data['contactId']?.toString() ?? '';
    final type = data['type'];
    final amount = _int(data['amountMinor'], min: 1);
    if (id.isEmpty || (type != 'collection' && type != 'payout')) {
      throw const FormatException('Ödeme bilgileri geçersiz.');
    }
    final contactRef = collection('contacts').doc(id);
    final paymentRef = collection('payments').doc();
    await firestore.runTransaction((tx) async {
      final contact = await tx.get(contactRef);
      if (!contact.exists) throw StateError('Cari bulunamadı.');
      final balance = (contact.data()?['balanceMinor'] as num?)?.toInt() ?? 0;
      final updated = balance + (type == 'collection' ? -amount : amount);
      if (updated.abs() > 1000000000000) {
        throw const FormatException('Bakiye limiti aşıldı.');
      }
      tx.update(contactRef, {'balanceMinor': updated});
      tx.set(paymentRef, {
        'contactId': id,
        'tradeId': null,
        'type': type,
        'amountMinor': amount,
        'auto': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return {'id': paymentRef.id};
  }

  /// Delete known Firestore collections in chunks (Spark has no Admin recursiveDelete).
  Future<void> deleteAccount() async {
    const names = [
      'categories', 'units', 'taxRates', 'products', 'contacts',
      'trades', 'stockMoves', 'payments', 'entitlements', 'billingEvents',
    ];
    for (final name in names) {
      while (true) {
        final records = await collection(name).limit(100).get();
        if (records.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final record in records.docs) {
          batch.delete(record.reference);
        }
        await batch.commit();
      }
    }
    await workspace.delete();
    await auth.currentUser!.delete();
  }
}

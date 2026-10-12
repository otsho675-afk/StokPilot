import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppApi {
  AppApi._();
  static final instance = AppApi._();
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  String get uid => auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get workspace => firestore.collection('workspaces').doc(uid);
  CollectionReference<Map<String, dynamic>> collection(String name) => workspace.collection(name);
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String name) => collection(name).snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> entitlement() => collection('entitlements').doc('current').snapshots();
  Future<void> initialize() async { await functions.httpsCallable('initializeWorkspace').call({'name': 'İşletmem'}); }
  Future<void> create(String name, Map<String, dynamic> data) async {
    if (name == 'products') {
      await call('createProduct', data);
      return;
    }
    await collection(name).add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }
  Future<void> edit(String name, String id, Map<String, dynamic> data) => collection(name).doc(id).update(data);
  Future<dynamic> call(String name, Map<String, dynamic> data) async => (await functions.httpsCallable(name).call(data)).data;
}

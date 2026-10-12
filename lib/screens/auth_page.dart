import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/ui.dart';

// Anonymous account linking retains the same UID and all its stock data.
class AuthActions {
  // Android may read the Web OAuth client from google-services.json. If it
  // cannot, pass GOOGLE_WEB_CLIENT_ID via --dart-define (web OAuth client).
  static const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static final Future<void> _googleInitialized = GoogleSignIn.instance.initialize(
    serverClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
  );
  static Future<void> guest() async => FirebaseAuth.instance.signInAnonymously();

  static Future<void> google({bool link = false}) async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      if (link && FirebaseAuth.instance.currentUser?.isAnonymous == true) {
        await FirebaseAuth.instance.currentUser!.linkWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithPopup(provider);
      }
      return;
    }
    await _googleInitialized;
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final token = googleAuth.idToken;
    if (token == null) throw FirebaseAuthException(code: 'missing-token', message: 'Google kimlik belirteci alınamadı.');
    final credential = GoogleAuthProvider.credential(idToken: token);
    if (link && FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
    } else {
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }

  static Future<void> apple({bool link = false}) async {
    final provider = AppleAuthProvider();
    if (kIsWeb) {
      if (link && FirebaseAuth.instance.currentUser?.isAnonymous == true) {
        await FirebaseAuth.instance.currentUser!.linkWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithPopup(provider);
      }
      return;
    }
    if (link && FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      await FirebaseAuth.instance.currentUser!.linkWithProvider(provider);
    } else {
      await FirebaseAuth.instance.signInWithProvider(provider);
    }
  }

  static String errorMessage(Object error) {
    if (error is GoogleSignInException) {
      final description = error.description ?? '';
      if (error.code == GoogleSignInExceptionCode.canceled &&
          (description.contains('Account reauth failed') ||
              description.contains('[16]'))) {
        return 'Google hesabı yeniden doğrulanamadı (16). Bu normal bir iptal '
            'olmayabilir. Firebase Google girişini, Android SHA-1/SHA-256 '
            'imzalarını, paket adını ve Web OAuth istemci kimliğini kontrol edin. '
            'Google Play Hizmetleri veya cihaz hesabı da bu hataya yol açabilir.';
      }
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Google ile giriş iptal edildi. Hesap seçiminden sonra kendiliğinden '
            'kapanıyorsa Firebase/OAuth yapılandırmasını kontrol edin.';
      }
      return 'Google ile giriş başarısız: '
          '${description.isNotEmpty ? description : error.code.name}';
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'operation-not-allowed') {
        return 'Bu giriş yöntemi Firebase Authentication > Sign-in method bölümünde kapalı. Anonymous, Google, Apple veya Email/Password yöntemini açın.';
      }
      if (error.code == 'credential-already-in-use' || error.code == 'email-already-in-use') {
        return 'Bu Google/Apple hesabına ait başka bir kayıt var. Misafir verilerini korumak için bu hesaplar otomatik birleştirilmez. Önce verilerinizi yedekleyin.';
      }
      return error.message ?? error.code;
    }
    return error.toString();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false, hidden = true;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> run(Future<void> Function() fn) async {
    setState(() => busy = true);
    try { await fn(); }
    catch (e) { if (mounted) notify(context, AuthActions.errorMessage(e), error: true); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> submit() => run(() async {
    if (email.text.trim().isEmpty || password.text.length < 6) {
      throw const FormatException('E-posta ve en az 6 karakter şifre gerekli.');
    }
    if (register) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
    }
  });
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(width: 72, height: 72, alignment: Alignment.center, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 36)),
    const SizedBox(height: 16), const Text('StokPilot', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: ink)),
    const Text('50 ürüne kadar ücretsiz • Sınırsız ürün için Pro', style: TextStyle(color: Colors.blueGrey)),
    const SizedBox(height: 20), DataPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(register ? 'Hesap oluştur' : 'Giriş yap', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta')),
      const SizedBox(height: 10), TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Şifre', suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
      const SizedBox(height: 15), FilledButton(onPressed: busy ? null : submit, child: Text(register ? 'Hesap oluştur' : 'E-posta ile giriş yap')),
      TextButton(onPressed: busy ? null : () => setState(() => register = !register), child: Text(register ? 'Zaten hesabım var' : 'Yeni hesap oluştur')),
      if (!register) TextButton(onPressed: busy ? null : () => run(() => FirebaseAuth.instance.sendPasswordResetEmail(email: email.text.trim())), child: const Text('Şifremi unuttum')),
      const Divider(height: 28),
      OutlinedButton.icon(onPressed: busy ? null : () => run(AuthActions.google), icon: const Icon(Icons.account_circle_outlined), label: const Text('Google ile devam et')),
      const SizedBox(height: 8),
      if (kIsWeb || Platform.isIOS) ...[
        OutlinedButton.icon(onPressed: busy ? null : () => run(AuthActions.apple), icon: const Icon(Icons.apple), label: const Text('Apple ile devam et')),
        const SizedBox(height: 8),
      ],
      FilledButton.tonalIcon(onPressed: busy ? null : () => run(AuthActions.guest), icon: const Icon(Icons.person_outline), label: const Text('Misafir olarak devam et')),
      const SizedBox(height: 8), const Text('Misafir verilerini korumak için Ayarlar’dan hesabınızı Google veya Apple ile bağlayın. Oturumu kapatıp yeni hesap açmak misafir verilerini taşımaz.', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
    ])),
  ])))));
}

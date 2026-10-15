import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/app_api.dart';
import 'services/billing.dart';
import 'screens/auth_page.dart';
import 'screens/shell.dart';
import 'widgets/ui.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const StokPilotApp());
  } catch (error) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 46,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase bağlantısı yapılandırılmamış',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Web uygulaması için Firebase ayarları eksik. Proje klasöründe FlutterFire CLI ile web platformunu yapılandırın.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'flutterfire configure --project=stokpilot-5bd2e --platforms=android,web',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StokPilotApp extends StatelessWidget {
  const StokPilotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'StokPilot',
    debugShowCheckedModeBanner: false,
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      visualDensity: VisualDensity.compact,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: green,
        selectionColor: Color(0xFFB5EADB),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: softGreen,
        checkmarkColor: green,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, height: 1.4),
        bodyLarge: TextStyle(color: ink, height: 1.4),
        titleLarge: TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          color: ink,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFBFCFE),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: green, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(110, 43),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(90, 44)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(105, 43),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: softGreen,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) return const AuthPage();
        return WorkspaceInitializer(
          key: ValueKey(snapshot.data!.uid),
          uid: snapshot.data!.uid,
        );
      },
    ),
  );
}

String readableInitializationError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Firestore yetkisi reddedildi. Firebase Spark güvenlik kurallarını yayımlayın.';
  }
  if (error is FirebaseException && error.code == 'unavailable') {
    return 'Firebase bağlantısı şu an kurulamadı. İnternet bağlantısını kontrol edin.';
  }
  return 'Başlatma başarısız oldu: $error';
}

class WorkspaceInitializer extends StatefulWidget {
  const WorkspaceInitializer({super.key, required this.uid});
  final String uid;
  @override
  State<WorkspaceInitializer> createState() => _WorkspaceInitializerState();
}

class _WorkspaceInitializerState extends State<WorkspaceInitializer> {
  late Future<void> future = setup();
  Future<void> setup() async {
    await AppApi.instance.initialize();
    await BillingService.instance.identify(widget.uid);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 45),
                  const SizedBox(height: 14),
                  const Text('Başlatma sırasında bağlantı hatası oluştu.'),
                  const SizedBox(height: 8),
                  Text(
                    readableInitializationError(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  FilledButton(
                    onPressed: () => setState(() => future = setup()),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const MainShell();
    },
  );
}

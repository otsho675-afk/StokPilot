import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_api.dart';

const ink = Color(0xFF142B32);
const green = Color(0xFF147D68);
const canvas = Color(0xFFF5F7F7);

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value, required this.icon, this.subtext});
  final String title, value;
  final IconData icon;
  final String? subtext;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7EBEC))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF657780), fontWeight: FontWeight.w600))),
        Icon(icon, color: green),
      ]),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(fontSize: 26, color: ink, fontWeight: FontWeight.w800)),
      if (subtext != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtext!, style: const TextStyle(fontSize: 12, color: Color(0xFF6E8488)))),
    ]),
  );
}
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 12, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF6C7E84))),
      ]),
      if (action != null) action!,
    ]),
  );
}
class BlankState extends StatelessWidget {
  const BlankState({super.key, required this.message, required this.icon});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 48, color: Colors.blueGrey.shade300), const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64777D))),
  ])));
}
class DataPanel extends StatelessWidget {
  const DataPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7EBEC))),
    padding: const EdgeInsets.all(18), child: child,
  );
}
void notify(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message), backgroundColor: error ? const Color(0xFFB73232) : ink,
    behavior: SnackBarBehavior.floating,
  ));
}
Future<bool> confirm(BuildContext context, String title, String body) async => await showDialog<bool>(
  context: context,
  builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [
    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Onayla')),
  ]),
) ?? false;

Future<void> requestAccountDeletion(BuildContext context) async {
  if (!await confirm(context, 'Hesabımı kalıcı sil',
      'Ürünler, cariler, stok ve tüm işletme geçmişi kalıcı olarak silinir. Aboneliğiniz otomatik iptal olmaz; önce Apple / Google mağaza aboneliklerinden iptal edin.')) { return; }
  if (!context.mounted) return;
  if (!await confirm(context, 'Son onay', 'Bu işlem geri alınamaz. Hesabınız ve kayıtlarınız silinsin mi?')) return;
  try {
    await AppApi.instance.call('deleteAccount', {'confirm': 'HESABIMI SIL'});
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    if (context.mounted) notify(context, 'Hesap silinemedi. Son 5 dakika içinde yeniden giriş yapmanız gerekebilir: $e', error: true);
  }
}

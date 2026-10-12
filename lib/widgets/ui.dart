import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_api.dart';

// StokPilot design system: consistent contrast and mobile-safe components.
const ink = Color(0xFF152C35);
const green = Color(0xFF087C68);
const canvas = Color(0xFFF4F7F8);
const muted = Color(0xFF657982);
const line = Color(0xFFE5ECEE);
const softGreen = Color(0xFFE6F6F0);
const amber = Color(0xFFBA741A);

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value,
    required this.icon, this.subtext, this.onTap});
  final String title, value;
  final IconData icon;
  final String? subtext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: const [BoxShadow(color: Color(0x07152C35), blurRadius: 20, offset: Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: softGreen, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: green, size: 20)),
          ]),
          const SizedBox(height: 16),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 27, color: ink, fontWeight: FontWeight.w900))),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext!, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ]),
      ),
    ),
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, required this.subtitle, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 480;
      final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900, color: ink, letterSpacing: -0.7)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 13, height: 1.4)),
      ]);
      if (narrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          heading, if (action != null) ...[const SizedBox(height: 14), action!],
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: heading),
        if (action != null) ...[const SizedBox(width: 14), action!],
      ]);
    }),
  );
}

class BlankState extends StatelessWidget {
  const BlankState({super.key, required this.message, required this.icon,
    this.title = 'Henüz kayıt yok', this.action});
  final String message, title;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: softGreen, shape: BoxShape.circle),
          child: Icon(icon, size: 34, color: green)),
        const SizedBox(height: 13),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ])),
  );
}

class DataPanel extends StatelessWidget {
  const DataPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: line),
      boxShadow: const [BoxShadow(color: Color(0x06152C35), blurRadius: 24, offset: Offset(0, 6))],
    ),
    padding: padding,
    child: child,
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
      if (subtitle != null) Text(subtitle!, style: const TextStyle(color: muted, fontSize: 12)),
    ])),
    if (trailing != null) trailing!,
  ]);
}

/// Stacks paired form inputs on narrow phones to avoid overflow.
class ResponsiveFields extends StatelessWidget {
  const ResponsiveFields({super.key, required this.first, required this.second});
  final Widget first, second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    if (size.maxWidth < 380) {
      return Column(children: [first, const SizedBox(height: 10), second]);
    }
    return Row(children: [
      Expanded(child: first), const SizedBox(width: 10), Expanded(child: second),
    ]);
  });
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}


/// A form dialog with finite dimensions, unlike AlertDialog's intrinsic-width
/// sizing, which can fail when forms contain LayoutBuilder/ResponsiveFields.
class ResponsiveFormDialog extends StatelessWidget {
  const ResponsiveFormDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const <Widget>[],
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final width = (size.width - 48).clamp(200.0, 560.0).toDouble();
    final maxHeight = (size.height - keyboard - 48).clamp(160.0, 9000.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 20,
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                  child: title,
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: content,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The route, not its awaiting caller, owns text controllers until unmount.
/// showDialog completes at pop, before the reverse transition finishes.
class _RouteControllerOwner extends StatefulWidget {
  const _RouteControllerOwner({
    required this.controllers,
    required this.child,
  });
  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_RouteControllerOwner> createState() => _RouteControllerOwnerState();
}

class _RouteControllerOwnerState extends State<_RouteControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<T?> showOwnedDialog<T>({
  required BuildContext context,
  required List<TextEditingController> controllers,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    builder: (routeContext) => _RouteControllerOwner(
      controllers: controllers,
      child: Builder(builder: builder),
    ),
  );
}

void notify(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFFB73232) : ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
  await showDialog<bool>(context: context,
    builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Onayla')),
    ])) ?? false;

Future<void> requestAccountDeletion(BuildContext context) async {
  if (!await confirm(context, 'Hesabımı kalıcı sil',
      'Ürün, cari ve işlem geçmişi silinir; kötüye kullanımı önlemek için minimal teknik kota sayacı saklanır. Aboneliğiniz otomatik iptal olmaz; mağazadan ayrıca iptal edin.')) {
    return;
  }
  if (!context.mounted) return;
  if (!await confirm(context, 'Son onay',
      'Bu işlem geri alınamaz. Hesabınız ve kayıtlarınız silinsin mi?')) {
    return;
  }
  try {
    await AppApi.instance.deleteAccount();
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    if (context.mounted) {
      notify(context,
          'Hesap silinemedi. Son 5 dakika içinde yeniden giriş yapmanız gerekebilir: $e',
          error: true);
    }
  }
}

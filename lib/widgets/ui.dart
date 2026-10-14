import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_api.dart';

// StokPilot design system: consistent contrast and mobile-safe components.
const ink = Color(0xFF172B43);
const green = Color(0xFF087F79);
const canvas = Color(0xFFF6F8FB);
const muted = Color(0xFF758397);
const line = Color(0xFFE6ECF1);
const softGreen = Color(0xFFE4F3F0);
const amber = Color(0xFFB87929);

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtext,
    this.onTap,
    this.accent = green,
  });
  final String title, value;
  final IconData icon;
  final String? subtext;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x07152842), blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w700)),
              ),
              if (onTap != null) const Icon(Icons.arrow_outward_rounded, size: 16, color: muted),
            ]),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(value, key: ValueKey<String>(value),
                  style: const TextStyle(color: ink, fontSize: 24,
                    fontWeight: FontWeight.w900, letterSpacing: -0.65)),
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(subtext!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 11)),
            ],
          ],
        ),
      ),
    ),
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title, subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: LayoutBuilder(builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26,
            fontWeight: FontWeight.w900, color: ink, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(
            color: muted, fontSize: 12.5, height: 1.45)),
        ],
      );
      if (constraints.maxWidth < 530) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          if (action != null) ...[const SizedBox(width: 16), action!],
        ],
      );
    }),
  );
}

class BlankState extends StatelessWidget {
  const BlankState({
    super.key,
    required this.message,
    required this.icon,
    this.title = 'Henüz kayıt yok',
    this.action,
  });
  final String message, title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFCFD),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: green),
        ),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center,
          style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.4)),
        if (action != null) ...[
          const SizedBox(height: 12), action!,
        ],
      ],
    ),
  );
}

class DataPanel extends StatelessWidget {
  const DataPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(color: Color(0x05152842), blurRadius: 20, offset: Offset(0, 5)),
      ],
    ),
    child: child,
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: ink, fontSize: 16, fontWeight: FontWeight.w900,
            letterSpacing: -0.25)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: const TextStyle(color: muted, fontSize: 11.5)),
          ],
        ],
      )),
      if (trailing != null) trailing!,
    ],
  );
}

/// Stacks paired form inputs on narrow phones to avoid overflow.
class ResponsiveFields extends StatelessWidget {
  const ResponsiveFields({
    super.key,
    required this.first,
    required this.second,
  });
  final Widget first, second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < 540) {
        return Column(children: [first, const SizedBox(height: 10), second]);
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 10),
          Expanded(child: second),
        ],
      );
    },
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// A form dialog with finite dimensions, unlike AlertDialog's intrinsic-width
/// sizing, which can fail when forms contain LayoutBuilder/ResponsiveFields.
/// Form sheets on phones, restrained dialogs on desktop.
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
    final dimensions = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final mobile = dimensions.width < 600;
    final maxHeight = (dimensions.height - keyboard - (mobile ? 8 : 24))
        .clamp(150.0, 9000.0).toDouble();

    final sheet = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 5),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCED7DF),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(mobile ? 17 : 21, 12, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFD),
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 18,
                      color: ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                    child: title,
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: muted, size: 21),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(mobile ? 17 : 21, 17, 17, 19),
              child: content,
            ),
          ),
          if (actions.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: line)),
              ),
              padding: EdgeInsets.fromLTRB(
                mobile ? 13 : 18,
                12,
                mobile ? 13 : 18,
                mobile ? 16 : 12,
              ),
              child: mobile
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - (actions.length - 1) * 9)
                            / actions.length;
                        return Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            for (final action in actions)
                              SizedBox(
                                width: width.clamp(104.0, 9000.0).toDouble(),
                                child: action,
                              ),
                          ],
                        );
                      },
                    )
                  : Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: actions,
                    ),
            ),
        ],
      ),
    );

    if (mobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Material(
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: sheet,
        ),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: SizedBox(
        width: (dimensions.width - 24).clamp(280.0, 540.0).toDouble(),
        child: sheet,
      ),
    );
  }
}

class CompactDateField extends StatelessWidget {
  const CompactDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final display = date == null ? 'Tarih seç'
        : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return Material(
      color: const Color(0xFFFBFCFE),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 57),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: softGreen, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.calendar_month_outlined, color: green, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 10)),
                const SizedBox(height: 3),
                Text(display, style: const TextStyle(
                  color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            )),
            if (date != null && onClear != null)
              IconButton(
                tooltip: '$label temizle',
                icon: const Icon(Icons.close_rounded, color: muted, size: 18),
                onPressed: onClear,
              )
            else
              const Icon(Icons.expand_more_rounded, color: muted, size: 19),
          ]),
        ),
      ),
    );
  }
}

/// A calendar bottom sheet on phones; the native date dialog on desktops.
/// Kept independent from form controllers so closing the calendar never
/// tears down the owning form or loses partially entered data.
Future<DateTime?> showPilotDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Tarih seç',
}) async {
  assert(!lastDate.isBefore(firstDate));
  final first = DateUtils.dateOnly(firstDate);
  final last = DateUtils.dateOnly(lastDate);
  final normalized = DateUtils.dateOnly(initialDate);
  final initial = normalized.isBefore(first)
      ? first
      : normalized.isAfter(last)
          ? last
          : normalized;

  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: title,
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
  }

  var selected = initial;
  final now = DateUtils.dateOnly(DateTime.now());
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, update) {
        final screen = MediaQuery.sizeOf(sheetContext);
        final height = (screen.height * 0.9).clamp(240.0, 610.0).toDouble();
        final choices = <(String, DateTime)>[
          ('Bugün', now),
          ('Dün', now.subtract(const Duration(days: 1))),
          ('7 gün önce', now.subtract(const Duration(days: 7))),
        ].where((item) =>
            !item.$2.isBefore(first) && !item.$2.isAfter(last)).toList();

        return Container(
          height: height,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              width: 42, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCDD7E0),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 0, 11, 10),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded, color: green, size: 23),
                const SizedBox(width: 11),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
                    Text(
                      '${selected.day.toString().padLeft(2, '0')}.${selected.month.toString().padLeft(2, '0')}.${selected.year}',
                      style: const TextStyle(fontSize: 12, color: muted)),
                  ],
                )),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: muted),
                ),
              ]),
            ),
            if (choices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 7),
                child: Wrap(spacing: 7, runSpacing: 6, children: [
                  for (final choice in choices)
                    ChoiceChip(
                      label: Text(choice.$1),
                      showCheckmark: false,
                      selected: DateUtils.isSameDay(selected, choice.$2),
                      onSelected: (_) => update(() => selected = choice.$2),
                    ),
                ]),
              ),
            const Divider(height: 1, color: line),
            Expanded(
              child: SingleChildScrollView(
                child: CalendarDatePicker(
                  key: ValueKey<DateTime>(selected),
                  initialDate: selected,
                  firstDate: first,
                  lastDate: last,
                  onDateChanged: (date) => update(() => selected = date),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFCFD),
                border: Border(top: BorderSide(color: line)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 16),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Vazgeç'),
                )),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(selected),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Tarihi seç'),
                )),
              ]),
            ),
          ]),
        );
      },
    ),
  );
}

/// Shared client-side paging for compact inventory, contacts and ledger views.
class ListPager extends StatelessWidget {
  const ListPager({
    super.key,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final int total, page, pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pages = ((total + pageSize - 1) ~/ pageSize).clamp(1, 999999);
      final current = page.clamp(0, pages - 1);
      final narrow = constraints.maxWidth < 500;
      final shown = <int>{
        0,
        if (pages > 1) pages - 1,
        for (var i = current - (narrow ? 0 : 1);
            i <= current + (narrow ? 0 : 1); i++)
          if (i >= 0 && i < pages) i,
      }.toList()..sort();

      final count = Text(
        total == 0
            ? '0 kayıt'
            : '${current * pageSize + 1}–${(current * pageSize + pageSize).clamp(0, total)} / $total kayıt',
        style: const TextStyle(color: muted, fontSize: 12),
      );
      final sizePicker = DropdownButton<int>(
        key: const ValueKey('pager-page-size'),
        value: pageSize,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: const [5, 10, 20, 50]
            .map((n) => DropdownMenuItem(
                  value: n,
                  child: Text('$n kayıt', style: TextStyle(fontSize: 12)),
                ))
            .toList(),
        onChanged: (n) {
          if (n != null) onPageSizeChanged(n);
        },
      );
      final buttons = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Önceki sayfa',
            visualDensity: VisualDensity.compact,
            onPressed: current == 0 ? null : () => onPageChanged(current - 1),
            icon: const Icon(Icons.chevron_left_rounded, size: 19),
          ),
          for (final index in shown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                width: 32,
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    backgroundColor: current == index ? softGreen : Colors.white,
                    side: BorderSide(color: current == index ? green : line),
                  ),
                  onPressed: () => onPageChanged(index),
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sonraki sayfa',
            visualDensity: VisualDensity.compact,
            onPressed: current >= pages - 1 ? null : () => onPageChanged(current + 1),
            icon: const Icon(Icons.chevron_right_rounded, size: 19),
          ),
        ],
      );

      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: count),
                      sizePicker,
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    key: const ValueKey('pager-mobile-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: buttons,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: count),
                  sizePicker,
                  const SizedBox(width: 10),
                  buttons,
                ],
              ),
      );
    },
  );
}

/// The route, not its awaiting caller, owns text controllers until unmount.
/// showDialog completes at pop, before the reverse transition finishes.
class _RouteControllerOwner extends StatefulWidget {
  const _RouteControllerOwner({required this.controllers, required this.child});
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
  Widget owner(BuildContext routeContext) => _RouteControllerOwner(
    controllers: controllers,
    child: Builder(builder: builder),
  );
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: owner,
    );
  }
  return showDialog<T>(context: context, builder: owner);
}

void notify(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB73232) : ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Onayla'),
              ),
            ],
          ),
    ) ??
    false;

Future<void> requestAccountDeletion(BuildContext context) async {
  if (!await confirm(
    context,
    'Hesabımı kalıcı sil',
    'Ürün, cari ve işlem geçmişi silinir; kötüye kullanımı önlemek için minimal teknik kota sayacı saklanır. Aboneliğiniz otomatik iptal olmaz; mağazadan ayrıca iptal edin.',
  )) {
    return;
  }
  if (!context.mounted) return;
  if (!await confirm(
    context,
    'Son onay',
    'Bu işlem geri alınamaz. Hesabınız ve kayıtlarınız silinsin mi?',
  )) {
    return;
  }
  try {
    await AppApi.instance.deleteAccount();
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    if (context.mounted) {
      notify(
        context,
        'Hesap silinemedi. Son 5 dakika içinde yeniden giriş yapmanız gerekebilir: $e',
        error: true,
      );
    }
  }
}

import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);
String money(int minor) => _currency.format(minor / 100);
String quantity(int milli) {
  final n = milli / 1000;
  return n == n.roundToDouble()
      ? n.toInt().toString()
      : n
          .toStringAsFixed(3)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
}

int parseMoney(String input) {
  final cleaned = input
      .trim()
      .replaceAll('₺', '')
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  final n = double.tryParse(cleaned);
  if (n == null || !n.isFinite || n < 0 || n > 1e10) {
    throw const FormatException('Geçerli bir tutar girin.');
  }
  return (n * 100).round();
}

int parseQty(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  final n = double.tryParse(normalized);
  if (n == null || !n.isFinite || n < 0 || n > 1e9) {
    throw const FormatException('Geçerli miktar girin.');
  }
  return (n * 1000).round();
}

String dateOf(dynamic value) {
  if (value == null) return '—';
  try {
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(value.toDate());
  } catch (_) {
    return '—';
  }
}

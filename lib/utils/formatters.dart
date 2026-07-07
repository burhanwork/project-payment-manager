import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _compactCurrency =
      NumberFormat.compactCurrency(symbol: '\$');
  static final _dateFormat = DateFormat('MMM dd, yyyy');
  static final _dateTimeFormat = DateFormat('MMM dd, yyyy - hh:mm a');
  static final _shortDate = DateFormat('dd MMM');

  static String currency(double amount) => _currencyFormat.format(amount);
  static String compactCurrency(double amount) =>
      _compactCurrency.format(amount);
  static String date(DateTime date) => _dateFormat.format(date);
  static String dateTime(DateTime date) => _dateTimeFormat.format(date);
  static String shortDate(DateTime date) => _shortDate.format(date);
  static String percentage(double value) =>
      '${value.toStringAsFixed(1)}%';

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 30) return _dateFormat.format(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Number and date rendering. Eastern Arabic digits by default in Arabic.
class Fmt {
  const Fmt(this.locale);
  final String locale;

  static Fmt of(BuildContext c) => Fmt(Localizations.localeOf(c).languageCode);
  bool get ar => locale != 'en';

  static const _eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String num(int n) {
    final s = n.toString();
    if (!ar) return s;
    return s.split('').map((c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57 ? _eastern[c.codeUnitAt(0) - 48] : c).join();
  }

  String _digits(String s) => ar ? s.replaceAllMapped(RegExp('[0-9]'), (m) => _eastern[int.parse(m[0]!)]) : s;

  String time(DateTime d) => _digits(DateFormat('h:mm', ar ? 'ar' : 'en').format(d)) + (ar ? (d.hour < 12 ? ' ص' : ' م') : (d.hour < 12 ? ' AM' : ' PM'));

  String date(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return ar ? 'اليوم' : 'Today';
    if (diff == 1) return ar ? 'غداً' : 'Tomorrow';
    if (diff == -1) return ar ? 'أمس' : 'Yesterday';
    return _digits(DateFormat(day.year == today.year ? 'd MMMM' : 'd MMMM y', ar ? 'ar' : 'en').format(d));
  }

  String dateTime(DateTime d, {bool dateOnly = false}) => dateOnly ? date(d) : '${date(d)} · ${time(d)}';

  String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return ar ? 'الآن' : 'now';
    if (diff.inMinutes < 60) return ar ? 'قبل ${num(diff.inMinutes)} د' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return ar ? 'قبل ${num(diff.inHours)} س' : '${diff.inHours}h ago';
    return date(d);
  }

  /// "٤ س" / "٣ أيام" until a deadline, or negative when overdue.
  String until(DateTime d) {
    final diff = d.difference(DateTime.now());
    final late = diff.isNegative;
    final a = diff.abs();
    final body = a.inHours < 1
        ? (ar ? '${num(a.inMinutes)} د' : '${a.inMinutes}m')
        : a.inHours < 24
            ? (ar ? '${num(a.inHours)} س' : '${a.inHours}h')
            : (ar ? '${num(a.inDays)} ي' : '${a.inDays}d');
    return late ? (ar ? 'تأخرت $body' : '$body late') : body;
  }

  /// Weekday-grouped header for notification lists.
  String dayHeader(DateTime d) => date(d);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  return parts.length == 1 ? parts.first.characters.first : parts.first.characters.first + parts[1].characters.first;
}

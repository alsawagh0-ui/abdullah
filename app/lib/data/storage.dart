import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// واجهة تخزين محلي بسيطة تسمح باستبدال الطبقة في الاختبارات.
///
/// كل بيانات المستخدم — خريطة العلاقات والدفتر — تبقى محلية على الجهاز؛
/// لا يرفع هذا التطبيق التجريبي أي شيء إلى خادم.
abstract class WajbStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
  Future<void> clear();
}

class MemoryStorage implements WajbStorage {
  Map<String, dynamic>? _data;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> data) async {
    _data = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  @override
  Future<void> clear() async => _data = null;
}

class PreferencesStorage implements WajbStorage {
  static const String _key = 'wajb.state.v1';

  @override
  Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

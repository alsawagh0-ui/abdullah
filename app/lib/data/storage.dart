import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

/// تخزين محلي مُعمّى (Keychain على iOS، Keystore/EncryptedSharedPreferences
/// على أندرويد) لبيانات حساسة: خريطة العلاقات ودفتر المعاملة بالمثل
/// وأرقام التواصل. حفظها بنص صريح في SharedPreferences يفضحها لأي عملية
/// أخرى تقرأ ملفات التطبيق على جهاز مُخترَق (root/jailbreak) أو في نسخة
/// احتياطية غير مُعمّاة — تناقض مباشر مع مبدأ الستر الذي يقوم عليه
/// المشروع.
class PreferencesStorage implements WajbStorage {
  PreferencesStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // نفس اسم المفتاح كان يُستخدم سابقاً في SharedPreferences غير المُعمّى؛
  // يُقرأ منه مرة واحدة للترحيل (انظر _migrateLegacy) ثم يُمحى من هناك.
  static const String _key = 'wajb.state.v1';

  final FlutterSecureStorage _secure;

  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _secure.read(key: _key) ?? await _migrateLegacy();
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  /// يقرأ النسخة القديمة من SharedPreferences غير المُعمّى إن وُجدت،
  /// ينقلها إلى التخزين المُعمّى، ويمحوها من مكانها القديم.
  Future<String?> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    await _secure.write(key: _key, value: raw);
    await prefs.remove(_key);
    return raw;
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    await _secure.write(key: _key, value: jsonEncode(data));
  }

  @override
  Future<void> clear() async {
    await _secure.delete(key: _key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Typed error carrying the stable code raised by the backend (doc 09 §4).
class ApiException implements Exception {
  ApiException(this.code, [this.detail = const {}]);
  final String code;
  final Map<String, dynamic> detail;

  @override
  String toString() => 'ApiException($code, $detail)';
}

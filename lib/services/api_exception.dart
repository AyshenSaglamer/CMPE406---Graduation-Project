class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
  });

  bool get isNetworkError => statusCode == 0;

  @override
  String toString() {
    return 'ApiException($statusCode): $message';
  }
}
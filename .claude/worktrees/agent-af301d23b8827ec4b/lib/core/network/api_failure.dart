class ApiFailure implements Exception {
  const ApiFailure({
    required this.message,
    this.code,
    this.fields = const {},
    this.statusCode,
  });

  final String message;
  final String? code;
  final Map<String, List<String>> fields;
  final int? statusCode;

  factory ApiFailure.fromResponse({
    required int? statusCode,
    required Object? data,
  }) {
    final error = data is Map<String, dynamic> && data['error'] is Map
        ? Map<String, dynamic>.from(data['error'] as Map)
        : <String, dynamic>{};
    final rawFields = error['fields'];
    final fields = <String, List<String>>{};
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        final value = entry.value;
        fields[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList()
            : [value.toString()];
      }
    }
    return ApiFailure(
      statusCode: statusCode,
      code: error['code'] as String?,
      message: error['message'] as String? ?? 'Unable to complete the request.',
      fields: fields,
    );
  }

  @override
  String toString() => message;
}

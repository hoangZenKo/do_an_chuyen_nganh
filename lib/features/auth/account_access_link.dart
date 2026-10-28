String? accountAccessTokenFromUri(Uri uri) {
  try {
    final fragment = uri.fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(uri.fragment);
    final token = fragment['token'] ?? uri.queryParameters['token'];
    if (token == null || !RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(token)) {
      return null;
    }
    return token;
  } on FormatException {
    return null;
  }
}

String? accountPasswordValidation(String? value) {
  final password = value ?? '';
  if (password.length < 12 || password.length > 128) {
    return 'Dùng từ 12 đến 128 ký tự.';
  }
  final missing = [
    if (!RegExp('[A-Z]').hasMatch(password)) 'chữ hoa',
    if (!RegExp('[a-z]').hasMatch(password)) 'chữ thường',
    if (!RegExp('[0-9]').hasMatch(password)) 'chữ số',
    if (!RegExp('[^A-Za-z0-9]').hasMatch(password)) 'ký tự đặc biệt',
  ];
  if (missing.isNotEmpty) {
    return 'Cần thêm: ${missing.join(', ')}.';
  }
  return null;
}

List<Map<String, dynamic>> parseFinanceStatementCsv(String input) {
  if (input.length > 1024 * 1024) {
    throw const FormatException('Sao kê tối đa 1 MB.');
  }
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false, closedQuote = false;
  final text = input.replaceFirst(RegExp(r'^\uFEFF'), '');
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (quoted) {
      if (char == '"') {
        if (index + 1 < text.length && text[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        field.write(char);
      }
    } else if (char == '"' && field.isEmpty && !closedQuote) {
      quoted = true;
    } else if (char == ',' || char == '\n' || char == '\r') {
      row.add(field.toString());
      field = StringBuffer();
      closedQuote = false;
      if (char != ',') {
        if (char == '\r' && index + 1 < text.length && text[index + 1] == '\n') {
          index++;
        }
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = [];
      }
    } else if (closedQuote || char == '"') {
      throw const FormatException('CSV có dấu nháy không hợp lệ.');
    } else {
      field.write(char);
    }
    if (rows.length > 1001) {
      throw const FormatException('Mỗi lần nhập tối đa 1.000 dòng.');
    }
  }
  if (quoted) throw const FormatException('CSV chưa đóng dấu nháy.');
  row.add(field.toString());
  if (row.any((value) => value.isNotEmpty)) rows.add(row);
  if (rows.length < 2 ||
      rows.length > 1001 ||
      rows.first.join(',') != 'externalId,amount,occurredAt,reference') {
    throw const FormatException(
        'Cần 1–1.000 dòng và header: externalId,amount,occurredAt,reference');
  }
  final ids = <String>{};
  return rows.skip(1).map((values) {
    if (values.length != 4) {
      throw const FormatException('Mỗi dòng phải có đúng 4 cột.');
    }
    final amount = int.tryParse(values[1]);
    final date = DateTime.tryParse(values[2]);
    if (values[0].trim().isEmpty ||
        values[0].length > 120 ||
        !ids.add(values[0]) ||
        amount == null ||
        amount <= 0 ||
        amount > 2147483647 ||
        date == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(values[2]) ||
        values[3].length > 500) {
      throw const FormatException(
          'Mã giao dịch phải duy nhất; số tiền nguyên dương; thời gian ISO 8601 có múi giờ.');
    }
    return <String, dynamic>{
      'externalId': values[0],
      'amount': amount,
      'occurredAt': date.toUtc().toIso8601String(),
      'reference': values[3]
    };
  }).toList();
}

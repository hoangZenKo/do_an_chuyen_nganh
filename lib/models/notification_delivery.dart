class NotificationDeliveryLog {
  const NotificationDeliveryLog({
    required this.id,
    required this.channel,
    required this.purpose,
    required this.recipient,
    required this.status,
    required this.payload,
    this.read = false,
    this.senderRole = '',
    this.direction = '',
    this.landlordName,
    this.tenantZaloPhone,
    this.tenantId,
    this.invoiceId,
    this.templateId,
    this.providerMessageId,
    this.errorCode,
    this.errorMessage,
    this.sentAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String channel;
  final String purpose;
  final String recipient;
  final String status;
  final Map<String, dynamic> payload;
  final bool read;
  final String senderRole;
  final String direction;
  final String? landlordName;
  final String? tenantZaloPhone;
  final String? tenantId;
  final String? invoiceId;
  final String? templateId;
  final String? providerMessageId;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get tenantName => _string(payload['tenant_name'], fallback: 'Tenant');
  String get roomName => _string(payload['room_name'], fallback: 'Phòng');
  String get billingMonth => _string(payload['billing_month'], fallback: '-');
  String get dueDateText => _string(payload['due_date'], fallback: '-');
  String get invoiceUrl => _string(payload['invoice_url']);
  String get customMessage => _string(payload['message_text']);
  bool get isTenantMessage =>
      purpose == 'tenant_manual_message' ||
      senderRole.toLowerCase() == 'tenant' ||
      direction.toLowerCase() == 'tenant_to_landlord';
  int get amount => _int(payload['amount']);
  bool get isZalo => channel.toLowerCase() == 'zalo';
  bool get isSent => status.toLowerCase() == 'sent';
  bool get isFailed => status.toLowerCase() == 'failed';
  bool get isSkipped => status.toLowerCase() == 'skipped';
  bool get isPending => status.toLowerCase() == 'pending';

  factory NotificationDeliveryLog.fromJson(Map<String, dynamic> json) {
    return NotificationDeliveryLog(
      id: json['id'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      recipient: json['recipient'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      tenantId: json['tenantId'] as String?,
      invoiceId: json['invoiceId'] as String?,
      templateId: json['templateId'] as String?,
      providerMessageId: json['providerMessageId'] as String?,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
      payload: _map(json['payload']),
      read: json['read'] == true,
      senderRole: _string(_map(json['payload'])['sender_role']),
      direction: _string(_map(json['payload'])['direction']),
      landlordName: _nullableString(_map(json['contact'])['landlordName']),
      tenantZaloPhone:
          _nullableString(_map(json['contact'])['tenantZaloPhone']),
      sentAt: _date(json['sentAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  String messageText() {
    if (customMessage.isNotEmpty) return customMessage;
    final amountText =
        amount > 0 ? '${_formatThousands(amount)} đ' : 'tiền trọ';
    final due = dueDateText == '-' ? 'hạn thanh toán' : 'hạn $dueDateText';
    return 'Chào $tenantName, phòng $roomName có hóa đơn tháng '
        '$billingMonth còn $amountText, $due. '
        'Anh/chị vui lòng thanh toán đúng hạn. Cảm ơn anh/chị.';
  }
}

List<NotificationDeliveryLog> notificationDeliveryListFromJson(
  Map<String, dynamic> json,
) {
  final raw = json['data'] is List ? json['data'] as List : const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(NotificationDeliveryLog.fromJson)
      .toList(growable: false);
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String _formatThousands(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer';
}

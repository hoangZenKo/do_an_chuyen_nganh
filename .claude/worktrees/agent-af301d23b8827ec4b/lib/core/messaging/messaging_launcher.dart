import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const messagingScheme = 'zalo-demo';
const messagingHost = 'compose';

Uri buildMessagingUri({
  String? tenantId,
  String? invoiceId,
  String? tenantName,
  String? roomName,
  String? template,
  String? message,
}) {
  final queryParameters = <String, String>{
    if (tenantId != null && tenantId.trim().isNotEmpty)
      'tenantId': tenantId.trim(),
    if (invoiceId != null && invoiceId.trim().isNotEmpty)
      'invoiceId': invoiceId.trim(),
    if (tenantName != null && tenantName.trim().isNotEmpty)
      'tenantName': tenantName.trim(),
    if (roomName != null && roomName.trim().isNotEmpty)
      'roomName': roomName.trim(),
    if (template != null && template.trim().isNotEmpty)
      'template': template.trim(),
    if (message != null && message.trim().isNotEmpty)
      'message': message.trim(),
  };
  return Uri(
    scheme: messagingScheme,
    host: messagingHost,
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
}

Future<bool> openMessagingApp(
  BuildContext context, {
  String? tenantId,
  String? invoiceId,
  String? tenantName,
  String? roomName,
  String? template,
  String? message,
}) async {
  final uri = buildMessagingUri(
    tenantId: tenantId,
    invoiceId: invoiceId,
    tenantName: tenantName,
    roomName: roomName,
    template: template,
    message: message,
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chưa mở được app Zalo: $uri')),
    );
  }
  return launched;
}

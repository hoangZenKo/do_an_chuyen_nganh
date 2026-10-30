import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tenant_portal/tenant_portal_providers.dart';

class MaintenanceAttachments extends ConsumerWidget {
  const MaintenanceAttachments({super.key, required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < urls.length; index++)
            ActionChip(
              avatar: const Icon(Icons.attachment_rounded, size: 16),
              label: Text('File ${index + 1}'),
              onPressed: () async {
                try {
                  final url =
                      await ref.read(uploadApiProvider).accessUrl(urls[index]);
                  if (!context.mounted) return;
                  final uri = Uri.parse(url);
                  if (!['http', 'https'].contains(uri.scheme) ||
                      !await launchUrl(uri,
                          mode: LaunchMode.externalApplication)) {
                    throw Exception('Cannot open attachment');
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Không mở được file đính kèm. Vui lòng thử lại.'),
                  ));
                }
              },
            ),
        ],
      );
}

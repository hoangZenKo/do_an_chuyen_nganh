import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../models/chatbot.dart';
import '../../auth/auth_providers.dart';
import '../../rooms/property_selection_provider.dart';
import '../chatbot_providers.dart';

Future<void> showChatSourceSheet(
    BuildContext context, WidgetRef ref, ChatSource source) {
  final session = ref.read(sessionControllerProvider).session;
  final propertyId = ref.read(selectedPropertyProvider);
  ref.invalidate(chatSourceProvider(source));
  return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
          heightFactor: 0.78,
          child: _SourceSheet(
              source: source, session: session, propertyId: propertyId)));
}

class _SourceSheet extends ConsumerWidget {
  const _SourceSheet(
      {required this.source, required this.session, required this.propertyId});
  final ChatSource source;
  final Object? session;
  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSession = ref.watch(sessionControllerProvider).session;
    if (!identical(session, currentSession) ||
        propertyId != ref.watch(selectedPropertyProvider)) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Phiên đăng nhập hoặc khu trọ đã thay đổi. Hãy mở lại nguồn.')));
    }
    final detail = ref.watch(chatSourceProvider(source));
    return SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Nguồn hướng dẫn',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: 'Đóng nguồn',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                  child: detail.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Đang kiểm tra nguồn')),
                error: (error, _) => SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(error is ApiFailure
                          ? error.message
                          : 'Không thể mở nguồn. Nguồn có thể đã được thu hồi.'),
                      const SizedBox(height: 12),
                      TextButton.icon(
                          onPressed: () =>
                              ref.invalidate(chatSourceProvider(source)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tải lại nguồn')),
                    ])),
                data: (detail) => SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(detail.source.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (detail.source.heading.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(detail.source.heading,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                      const SizedBox(height: 20),
                      SelectableText(detail.text,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.6)),
                    ])),
              )),
            ])));
  }
}

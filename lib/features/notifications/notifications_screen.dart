import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/landlord_notification.dart';
import 'notifications_providers.dart';
import '../auth/auth_navigation.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(title: const Text('Thông báo'), actions: [
        IconButton(
            tooltip: 'Trung tâm gửi thông báo',
            onPressed: () =>
                context.push('$p1OperationsRoute?section=announcements'),
            icon: const Icon(Icons.campaign_rounded))
      ]),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: bundleAsync.when(
          loading: () => const _LoadingList(),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [_Card(child: Text('$error'))],
          ),
          data: (bundle) {
            final items = bundle.items;
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [_Card(child: Text('Không có thông báo.'))],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SummaryCard(summary: bundle.summary);
                }
                return _NotificationTile(item: items[index - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final NotificationSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const Icon(Icons.notifications_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${summary.unread} chưa đọc / ${summary.total} thông báo',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final LandlordNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: InkWell(
        onTap: () async {
          if (!item.isRead) {
            await ref
                .read(notificationsControllerProvider.notifier)
                .markRead(item.id);
          }
          if (item.actionRoute.isNotEmpty && context.mounted) {
            context.push(item.actionRoute);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon(item.kind), color: _color(item.severity)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.body),
                  if (item.dueAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Hạn: ${formatDate(item.dueAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8891A8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _Card(child: SizedBox(height: 70)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3348)),
      ),
      child: child,
    );
  }
}

IconData _icon(String kind) {
  if (kind.contains('invoice') || kind.contains('payment')) {
    return Icons.payments_rounded;
  }
  if (kind.contains('maintenance')) return Icons.construction_rounded;
  if (kind.contains('lease')) return Icons.event_busy_rounded;
  if (kind.contains('inspection')) return Icons.fact_check_rounded;
  return Icons.notifications_rounded;
}

Color _color(String severity) => switch (severity) {
      'danger' => const Color(0xFFDC2626),
      'warning' => const Color(0xFFF59E0B),
      _ => AppTheme.primary,
    };

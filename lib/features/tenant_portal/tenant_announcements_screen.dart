import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../listings/listing_widgets.dart';
import '../operations/p1_operations_screen.dart';
import '../operations/p1_providers.dart';

class TenantAnnouncementsScreen extends ConsumerWidget {
  const TenantAnnouncementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListingTheme(
      child: Scaffold(
          appBar: AppBar(title: const Text('Thông báo từ chủ trọ')),
          body: ref.watch(tenantAnnouncementsProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$error'),
                  TextButton(
                      onPressed: () =>
                          ref.invalidate(tenantAnnouncementsProvider),
                      child: const Text('Thử lại'))
                ])),
                data: (items) => RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(tenantAnnouncementsProvider),
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (items.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Chưa có thông báo từ chủ trọ.',
                                    textAlign: TextAlign.center)),
                          ...items.map((item) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              leading: Icon(
                                  item.isRead
                                      ? Icons.mark_email_read_outlined
                                      : Icons.mark_email_unread_rounded,
                                  color:
                                      item.isRead ? kAirbnbMuted : kAirbnbRose),
                              title: Text(item.title,
                                  style: TextStyle(
                                      fontWeight: item.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w800)),
                              subtitle: Text(
                                  '${formatDate(item.sendAt.toLocal())} · ${item.isRead ? 'Đã xác nhận' : 'Chưa xác nhận'}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => ListingTheme(child: AnnouncementDetailScreen(item: item, tenant: true))))))
                        ])),
              )));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room_listing.dart';
import '../auth/auth_providers.dart';
import 'discovery_tools.dart';
import 'listing_detail_screen.dart';
import 'listing_widgets.dart';

class SavedSearchesScreen extends ConsumerStatefulWidget {
  const SavedSearchesScreen({super.key});
  @override
  ConsumerState<SavedSearchesScreen> createState() =>
      _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends ConsumerState<SavedSearchesScreen> {
  int _page = 1;
  bool _busy = false;
  Future<void> _run(Future<void> Function(DiscoveryToolsApi) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(discoveryToolsProvider));
      ref.invalidate(savedSearchesProvider);
      ref.invalidate(searchAlertsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa thực hiện được. Hãy thử lại.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    if (session?.user.role != 'tenant') {
      return const Scaffold(
          body: Center(child: Text('Hãy đăng nhập tài khoản sinh viên.')));
    }
    return ListingTheme(
        child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                  title: const Text('Tìm kiếm đã lưu'),
                  bottom: const TabBar(tabs: [
                    Tab(text: 'Bộ lọc của tôi'),
                    Tab(text: 'Tin mới phù hợp')
                  ])),
              body: TabBarView(children: [
                ref.watch(savedSearchesProvider).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => Center(
                          child: TextButton(
                              onPressed: () =>
                                  ref.invalidate(savedSearchesProvider),
                              child: const Text('Tải lại bộ lọc'))),
                      data: (items) => ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                                'Tối đa 10 bộ lọc. Thông báo xuất hiện trong app khi có tin mới sau thời điểm lưu. Bật lại sẽ bắt đầu theo dõi từ hiện tại.'),
                            const SizedBox(height: 16),
                            if (items.isEmpty)
                              const Text(
                                  'Chưa có bộ lọc. Chọn bộ lọc ở Khám phá rồi nhấn “Lưu tìm kiếm”.'),
                            for (final item in items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item['name'] as String),
                                subtitle: Text(item['enabled'] == true
                                    ? 'Đang theo dõi · Nhấn để áp dụng'
                                    : 'Đã tạm dừng · Nhấn để áp dụng'),
                                onTap: () => Navigator.pop(
                                    context,
                                    ListingQuery.fromJson(item['filters']
                                        as Map<String, dynamic>)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                          value: item['enabled'] == true,
                                          onChanged: _busy
                                              ? null
                                              : (value) => _run((api) =>
                                                  api.status(
                                                      item['id'] as String,
                                                      value))),
                                      IconButton(
                                          tooltip: 'Xóa bộ lọc',
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: _busy
                                              ? null
                                              : () => _run((api) => api.remove(
                                                  item['id'] as String))),
                                    ]),
                              ),
                          ]),
                    ),
                ref.watch(searchAlertsProvider(_page)).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => Center(
                          child: TextButton(
                              onPressed: () =>
                                  ref.invalidate(searchAlertsProvider),
                              child: const Text('Tải lại thông báo'))),
                      data: (result) {
                        final items = (result['data'] as List)
                            .cast<Map<String, dynamic>>();
                        final meta = result['meta'] as Map<String, dynamic>;
                        return RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(searchAlertsProvider);
                              await ref
                                  .read(searchAlertsProvider(_page).future);
                            },
                            child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Text(
                                      '${meta['unread']} thông báo chưa đọc · Kiểm tra nền mỗi 15 phút và khi tải lại.'),
                                  if (items.isEmpty)
                                    const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 32),
                                        child: Text(
                                            'Chưa có tin mới phù hợp. Tin đã có trước lúc lưu không tạo thông báo.')),
                                  for (final item in items)
                                    ListTile(
                                      leading: Icon(item['readAt'] == null
                                          ? Icons.mark_email_unread_outlined
                                          : Icons.drafts_outlined),
                                      title: Text(
                                          item['listing']['title'] as String),
                                      subtitle: Text(
                                          '${item['search']['name']}\n${item['listing']['publicAddress']}'),
                                      onTap: _busy
                                          ? null
                                          : () async {
                                              await _run((api) => api
                                                  .read(item['id'] as String));
                                              if (context.mounted) {
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            ListingDetailScreen(
                                                                id: item['listing']
                                                                        ['id']
                                                                    as String)));
                                              }
                                            },
                                    ),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                            onPressed: _page > 1
                                                ? () => setState(() => _page--)
                                                : null,
                                            child: const Text('Trước')),
                                        Text('Trang $_page'),
                                        TextButton(
                                            onPressed: _page * 20 <
                                                    (meta['total'] as int)
                                                ? () => setState(() => _page++)
                                                : null,
                                            child: const Text('Sau')),
                                      ]),
                                ]));
                      },
                    ),
              ]),
            )));
  }
}

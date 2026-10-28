import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/student_discovery.dart';
import '../auth/auth_providers.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';

final _listingReportsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, page) {
  ref.watch(sessionIdentityProvider);
  return ref.watch(managedListingsRepositoryProvider).reports(page);
});

class ListingReportsScreen extends ConsumerStatefulWidget {
  const ListingReportsScreen({super.key});
  @override
  ConsumerState<ListingReportsScreen> createState() =>
      _ListingReportsScreenState();
}

class _ListingReportsScreenState extends ConsumerState<ListingReportsScreen> {
  late final String? _identity;
  var _page = 1;
  var _busy = false;
  @override
  void initState() {
    super.initState();
    _identity = ref.read(sessionIdentityProvider);
  }

  Future<void> _review(String id, String status) async {
    final note = await showDialog<String>(
        context: context, builder: (_) => _ReportReviewDialog());
    if (note == null ||
        !mounted ||
        ref.read(sessionIdentityProvider) != _identity) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(managedListingsRepositoryProvider)
          .reviewReport(id, status, note);
      if (mounted && ref.read(sessionIdentityProvider) == _identity) {
        ref.invalidate(_listingReportsProvider);
      }
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == _identity) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    if (session?.user.role != 'admin' || session?.user.id != _identity) {
      return const Scaffold(
          body: Center(
              child: Text(
                  'Phiên quản trị đã thay đổi. Hãy quay lại và mở lại trang.')));
    }
    return ListingTheme(
        child: Scaffold(
            appBar: AppBar(title: const Text('Báo cáo tin đăng')),
            body: ref.watch(_listingReportsProvider(_page)).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListingMessage(
                      title: 'Chưa tải được báo cáo',
                      message: listingError(error),
                      onRetry: () =>
                          ref.invalidate(_listingReportsProvider(_page))),
                  data: (result) {
                    final reports = result['data'] as List;
                    final total = (result['meta']['total'] as num).toInt();
                    return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                              'Xử lý báo cáo không tự động ẩn tin. Nếu cần ẩn, quay về Kiểm duyệt tin đăng để thực hiện và ghi lý do.'),
                          if (reports.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Chưa có báo cáo.')),
                          for (final raw in reports)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              raw['listing']['title'] as String,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800)),
                                          Text(listingReportReasons[
                                                  raw['reason']] ??
                                              raw['reason'] as String),
                                          Text(raw['detail'] as String),
                                          Text('Trạng thái: ${raw['status']}'),
                                          if (raw['reviewNote'] != null)
                                            Text(
                                                'Kết quả: ${raw['reviewNote']}'),
                                          if (raw['status'] == 'OPEN')
                                            Wrap(spacing: 12, children: [
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _review(
                                                          raw['id'] as String,
                                                          'RESOLVED'),
                                                  child:
                                                      const Text('Đã xử lý')),
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _review(
                                                          raw['id'] as String,
                                                          'DISMISSED'),
                                                  child: const Text(
                                                      'Không đủ căn cứ')),
                                            ]),
                                        ]))),
                          Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton(
                                    onPressed: _page > 1 && !_busy
                                        ? () => setState(() => _page--)
                                        : null,
                                    child: const Text('Trang trước')),
                                Text('Trang $_page'),
                                OutlinedButton(
                                    onPressed: _page * 12 < total && !_busy
                                        ? () => setState(() => _page++)
                                        : null,
                                    child: const Text('Trang sau')),
                              ]),
                        ]);
                  },
                )));
  }
}

class _ReportReviewDialog extends StatefulWidget {
  @override
  State<_ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<_ReportReviewDialog> {
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Ghi nhận kết quả kiểm tra'),
          content: Form(
              key: _form,
              child: TextFormField(
                controller: _note,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Nội dung đã kiểm tra / xử lý'),
                validator: (value) => (value?.trim().length ?? 0) < 5
                    ? 'Nhập ít nhất 5 ký tự'
                    : null,
              )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _note.text.trim());
                  }
                },
                child: const Text('Lưu kết quả')),
          ]);
}

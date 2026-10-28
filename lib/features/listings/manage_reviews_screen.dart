import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/room_review.dart';
import '../auth/auth_providers.dart';
import 'listing_widgets.dart';
import 'review_widgets.dart';
import 'reviews_providers.dart';

class ManageReviewsScreen extends ConsumerStatefulWidget {
  const ManageReviewsScreen({super.key, this.admin = false});

  final bool admin;

  @override
  ConsumerState<ManageReviewsScreen> createState() =>
      _ManageReviewsScreenState();
}

class _ManageReviewsScreenState extends ConsumerState<ManageReviewsScreen> {
  late final String? _accountId;
  int _page = 1;
  String _status = 'PENDING';
  bool _replies = false;

  @override
  void initState() {
    super.initState();
    _accountId = ref.read(sessionIdentityProvider);
  }

  ManagedReviewsQuery get _query =>
      (admin: widget.admin, page: _page, status: _status, replies: _replies);

  Future<void> _refresh() async {
    ref.invalidate(managedReviewsProvider(_query));
    try {
      await ref.read(managedReviewsProvider(_query).future);
    } catch (_) {}
  }

  Future<void> _act(RoomReview review, [String? status]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ListingTheme(
        child: _ReviewActionDialog(
          review: review,
          accountId: _accountId,
          status: status,
          reply: _replies,
        ),
      ),
    );
    if (!mounted || ref.read(sessionIdentityProvider) != _accountId) return;
    if (result == true) {
      ref.invalidate(managedReviewsProvider);
      ref.invalidate(publicReviewsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.admin
            ? 'Đã cập nhật kết quả kiểm duyệt.'
            : 'Đã gửi phản hồi, chờ kiểm duyệt.'),
      ));
    } else {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    if (_accountId == null ||
        session?.user.id != _accountId ||
        session?.user.role != (widget.admin ? 'admin' : 'landlord')) {
      return const Scaffold(
        body: ListingMessage(
          title: 'Phiên quản lý đã thay đổi',
          message: 'Hãy mở lại trang từ tài khoản có quyền.',
        ),
      );
    }
    final reviews = ref.watch(managedReviewsProvider(_query));
    return ListingTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.admin ? 'Kiểm duyệt đánh giá' : 'Đánh giá của người thuê'),
          actions: [
            IconButton(
              tooltip: 'Tải lại đánh giá',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(widget.admin
                    ? 'Đánh giá và phản hồi được kiểm duyệt riêng. Chỉ nội dung đã duyệt mới hiển thị công khai.'
                    : 'Đánh giá đến từ người có lịch sử thuê. Phản hồi của bạn sẽ được kiểm duyệt trước khi công khai.'),
                const SizedBox(height: 20),
                if (widget.admin) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final replies in [false, true])
                      ChoiceChip(
                        label: Text(replies
                            ? 'Phản hồi chủ trọ'
                            : 'Đánh giá người thuê'),
                        selected: _replies == replies,
                        onSelected: (_) => setState(() {
                          _replies = replies;
                          _page = 1;
                        }),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Trạng thái kiểm duyệt'),
                    items: [
                      for (final status in [
                        'PENDING',
                        'APPROVED',
                        'REJECTED',
                        'HIDDEN'
                      ])
                        DropdownMenuItem(
                            value: status,
                            child: Text(reviewStatusLabel(status))),
                    ],
                    onChanged: (status) => setState(() {
                      _status = status!;
                      _page = 1;
                    }),
                  ),
                  const SizedBox(height: 20),
                ],
                reviews.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Column(children: [
                    Text('Chưa tải được đánh giá: ${listingError(error)}'),
                    TextButton(
                        onPressed: _refresh, child: const Text('Thử lại')),
                  ]),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          '${data.total} ${widget.admin && _replies ? 'phản hồi' : 'đánh giá'}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      if (data.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text('Chưa có nội dung trong danh sách này.'),
                        ),
                      for (final review in data.items)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: kAirbnbLine),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReviewContent(review: review, management: true),
                              const SizedBox(height: 16),
                              if (!widget.admin)
                                OutlinedButton.icon(
                                  onPressed: () => _act(review),
                                  icon: const Icon(Icons.reply_outlined),
                                  label: Text(review.replyBody == null
                                      ? 'Viết phản hồi'
                                      : 'Sửa phản hồi'),
                                )
                              else
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final entry in const {
                                    'APPROVED': 'Duyệt công khai',
                                    'REJECTED': 'Từ chối',
                                    'HIDDEN': 'Ẩn nội dung',
                                  }.entries)
                                    if (entry.key !=
                                        (_replies
                                            ? review.replyStatus
                                            : review.status))
                                      OutlinedButton(
                                        onPressed: () =>
                                            _act(review, entry.key),
                                        child: Text(entry.value),
                                      ),
                                ]),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                            child: const Text('Trang trước'),
                          ),
                          Text('Trang $_page'),
                          TextButton(
                            onPressed: data.hasNext
                                ? () => setState(() => _page++)
                                : null,
                            child: const Text('Trang sau'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewActionDialog extends ConsumerStatefulWidget {
  const _ReviewActionDialog(
      {required this.review,
      required this.accountId,
      required this.reply,
      this.status});

  final RoomReview review;
  final String? accountId, status;
  final bool reply;

  @override
  ConsumerState<_ReviewActionDialog> createState() =>
      _ReviewActionDialogState();
}

class _ReviewActionDialogState extends ConsumerState<_ReviewActionDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
        text: widget.status == null ? widget.review.replyBody : '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final session = ref.read(sessionControllerProvider).session;
    if (session?.user.id != widget.accountId ||
        session?.user.role != (widget.status == null ? 'landlord' : 'admin')) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(reviewsRepositoryProvider);
      if (widget.status == null) {
        await repository.reply(widget.review, _text.text);
      } else {
        await repository.moderate(widget.review, widget.status!, _text.text,
            reply: widget.reply);
      }
      if (mounted && ref.read(sessionIdentityProvider) == widget.accountId) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = listingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final active = session?.user.id == widget.accountId &&
        session?.user.role == (widget.status == null ? 'landlord' : 'admin');
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(widget.status == null
            ? 'Phản hồi đánh giá'
            : '${reviewStatusLabel(widget.status!)} · ${widget.reply ? 'Phản hồi' : 'Đánh giá'}'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!active)
                const Text(
                    'Phiên quản lý đã thay đổi. Hãy đóng và mở lại trang.'),
              if (active) ...[
                if (widget.status == null)
                  const Text(
                      'Phản hồi cần được kiểm duyệt trước khi hiển thị.'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _text,
                  enabled: active && !_busy,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: widget.status == null ? 2000 : 1000,
                  decoration: InputDecoration(
                      labelText: widget.status == null
                          ? 'Nội dung phản hồi'
                          : 'Lý do kiểm duyệt'),
                  validator: (value) => (value?.trim().length ?? 0) < 5
                      ? 'Nhập ít nhất 5 ký tự.'
                      : null,
                ),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Đóng')),
          FilledButton(
            onPressed: _busy || !active ? null : _submit,
            child: Text(_busy ? 'Đang gửi…' : 'Xác nhận'),
          ),
        ],
      ),
    );
  }
}

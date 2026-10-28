import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room_review.dart';
import '../auth/auth_providers.dart';
import 'listing_widgets.dart';
import 'review_widgets.dart';
import 'reviews_providers.dart';

class ReviewComposer extends ConsumerStatefulWidget {
  const ReviewComposer({super.key, required this.contextData});
  final ReviewContext contextData;
  @override
  ConsumerState<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends ConsumerState<ReviewComposer> {
  final _body = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _scores = <String, int>{for (final key in reviewCriteria.keys) key: 4};
  bool _busy = false;
  String? _error;
  late final String? _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = ref.read(sessionIdentityProvider);
    final review = widget.contextData.review;
    if (review != null) {
      _body.text = review.body;
      _scores.addAll(review.scores);
    }
  }

  @override
  void didUpdateWidget(covariant ReviewComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextData.leaseId != widget.contextData.leaseId ||
        oldWidget.contextData.review?.version !=
            widget.contextData.review?.version) {
      final review = widget.contextData.review;
      _body.text = review?.body ?? '';
      for (final key in reviewCriteria.keys) {
        _scores[key] = review?.scores[key] ?? 4;
      }
      _error = null;
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_sameAccount || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewsRepositoryProvider).submit(
          widget.contextData.leaseId, _scores, _body.text,
          existing: widget.contextData.review);
      if (mounted && _sameAccount) {
        ref.invalidate(reviewContextProvider(widget.contextData.leaseId));
        ref.invalidate(publicReviewsProvider);
        ref.invalidate(managedReviewsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi đánh giá, chờ kiểm duyệt.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = listingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _sameAccount =>
      _accountId != null &&
      ref.read(sessionIdentityProvider) == _accountId &&
      ref.read(sessionControllerProvider).session?.user.role == 'tenant';

  Future<void> _withdraw() async {
    if (_busy || !_sameAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gỡ đánh giá công khai?'),
        content: const Text(
            'Đánh giá và phản hồi sẽ không còn hiển thị. Bạn có thể chỉnh sửa rồi gửi duyệt lại.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gỡ đánh giá')),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_sameAccount) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .withdraw(widget.contextData.review!);
      if (mounted && _sameAccount) {
        ref.invalidate(reviewContextProvider(widget.contextData.leaseId));
        ref.invalidate(publicReviewsProvider);
        ref.invalidate(managedReviewsProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã gỡ đánh giá.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = listingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    if (!_sameAccount) {
      return const Text('Phiên người thuê đã thay đổi. Hãy mở lại hợp đồng.');
    }
    final review = widget.contextData.review;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(review == null ? 'Đánh giá sau khi thuê' : 'Cập nhật đánh giá',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(widget.contextData.reason ??
          'Đánh giá của bạn được gắn với lịch sử thuê và sẽ được kiểm duyệt trước khi công khai.'),
      if (review != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'Trạng thái: ${review.withdrawn ? 'Đã gỡ' : reviewStatusLabel(review.status)}')),
      if (review?.moderationNote != null)
        Text('Ghi chú kiểm duyệt: ${review!.moderationNote}'),
      if (review?.replyBody != null)
        Text('Phản hồi của chủ trọ: ${review!.replyBody}'),
      if (widget.contextData.eligible) ...[
        const SizedBox(height: 12),
        Form(
            key: _form,
            child: Column(children: [
              for (final entry in reviewCriteria.entries)
                Row(children: [
                  Expanded(child: Text(entry.value)),
                  DropdownButton<int>(
                      hint: Text(entry.value),
                      value: _scores[entry.key],
                      onChanged: _busy
                          ? null
                          : (value) =>
                              setState(() => _scores[entry.key] = value!),
                      items: [
                        for (var score = 1; score <= 5; score++)
                          DropdownMenuItem(
                              value: score, child: Text('$score/5'))
                      ]),
                ]),
              TextFormField(
                  controller: _body,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 3000,
                  decoration: const InputDecoration(
                      labelText: 'Chia sẻ trải nghiệm thực tế'),
                  validator: (value) => (value?.trim().length ?? 0) < 20
                      ? 'Viết ít nhất 20 ký tự.'
                      : null),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_error != null)
                TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref.invalidate(
                            reviewContextProvider(widget.contextData.leaseId)),
                    child: const Text('Tải lại đánh giá')),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Gửi đánh giá')),
              if (review != null && !review.withdrawn)
                TextButton(
                    onPressed: _busy ? null : _withdraw,
                    child: const Text('Gỡ đánh giá')),
            ])),
      ],
    ]);
  }
}

class PublicReviewsSection extends ConsumerStatefulWidget {
  const PublicReviewsSection({super.key, required this.listingId});
  final String listingId;
  @override
  ConsumerState<PublicReviewsSection> createState() =>
      _PublicReviewsSectionState();
}

class _PublicReviewsSectionState extends ConsumerState<PublicReviewsSection> {
  int _page = 1;

  @override
  void didUpdateWidget(covariant PublicReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) _page = 1;
  }

  PublicReviewsQuery get _query => (listingId: widget.listingId, page: _page);

  @override
  Widget build(BuildContext context) =>
      ref.watch(publicReviewsProvider(_query)).when(
          loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator()),
          error: (error, _) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chưa tải được đánh giá: ${listingError(error)}'),
                TextButton(
                    onPressed: () =>
                        ref.invalidate(publicReviewsProvider(_query)),
                    child: const Text('Thử lại')),
              ]),
          data: (page) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Đánh giá từ người đã thuê (${page.count})',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (page.count == 0)
                  const Text('Chưa có đánh giá đã được kiểm duyệt.'),
                if (page.count > 0) ...[
                  Text(
                      '${page.overall?.toStringAsFixed(1) ?? '-'}/5 · Điểm từ đánh giá đã duyệt'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    for (final entry in reviewCriteria.entries)
                      Text(
                          '${entry.value}: ${page.averages[entry.key]?.toStringAsFixed(1) ?? '-'}/5'),
                  ]),
                ],
                for (final review in page.page.items)
                  Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: ReviewContent(review: review)))),
                if (_page > 1 || page.page.hasNext)
                  Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                            child: const Text('Trang trước')),
                        Text('Trang $_page'),
                        TextButton(
                            onPressed: page.page.hasNext
                                ? () => setState(() => _page++)
                                : null,
                            child: const Text('Trang sau')),
                      ]),
              ]));
}

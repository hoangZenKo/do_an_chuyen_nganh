import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/format.dart';
import '../../models/room_listing.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_navigation.dart';
import 'listing_form_screen.dart';
import 'listing_widgets.dart';
import 'campus_management_screen.dart';
import 'listings_providers.dart';
import 'listing_reports_screen.dart';
import 'listing_verification_dialog.dart';
import 'viewing_slots_screen.dart';

class ManageListingsScreen extends ConsumerStatefulWidget {
  const ManageListingsScreen({super.key, this.admin = false});
  final bool admin;
  @override
  ConsumerState<ManageListingsScreen> createState() =>
      _ManageListingsScreenState();
}

class _ManageListingsScreenState extends ConsumerState<ManageListingsScreen> {
  String? _accountId;
  @override
  void initState() {
    super.initState();
    _accountId = ref.read(sessionIdentityProvider);
  }

  int _page = 1;
  String? _status;
  bool _busy = false;
  Future<void> _verify(RoomListing listing) async {
    final result = await showDialog<ListingVerification>(
        context: context,
        builder: (_) =>
            ListingTheme(child: ListingVerificationDialog(listing: listing)));
    if (result == null ||
        !mounted ||
        ref.read(sessionIdentityProvider) != _accountId) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(managedListingsRepositoryProvider).verify(listing,
          landlordVerified: result.landlordVerified,
          roomInspected: result.roomInspected,
          note: result.note);
      if (mounted && ref.read(sessionIdentityProvider) == _accountId) {
        ref.invalidate(managedListingsProvider);
        ref.invalidate(publicListingsProvider);
        ref.invalidate(publicListingDetailProvider);
      }
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == _accountId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ManagedListingsQuery get _query =>
      (admin: widget.admin, page: _page, status: _status);

  Future<void> _action(RoomListing listing, String action) async {
    final needsReason = action == 'REJECT' || action == 'HIDE';
    final labels = {
      'PUBLISH': 'Duyệt và công khai',
      'REJECT': 'Từ chối',
      'HIDE': 'Ẩn tin',
      'submit': 'Gửi duyệt',
      'hide': 'Ẩn tin',
      'confirm-availability': 'Xác nhận còn phòng'
    };
    final result = await showDialog<String>(
        context: context,
        builder: (context) => ListingTheme(
                child: _ListingActionDialog(
              title: labels[action]!,
              listingTitle: listing.title,
              needsReason: needsReason,
              publish: action == 'PUBLISH',
              accountId: _accountId,
            )));
    if (result == null ||
        !mounted ||
        ref.read(sessionIdentityProvider) != _accountId) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(managedListingsRepositoryProvider)
          .action(listing, action, note: needsReason ? result : null);
      ref.invalidate(managedListingsProvider);
      ref.invalidate(publicListingsProvider);
      ref.invalidate(publicListingDetailProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingError(error))));
      }
      ref.invalidate(managedListingsProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _preview(RoomListing listing) {
    showDialog<void>(
        context: context,
        builder: (context) => ListingTheme(
            child: _ListingSessionBoundary(
                accountId: _accountId,
                child: AlertDialog(
                  title: Text(listing.title),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            if (listing.imageUrls.isNotEmpty)
                              SizedBox(
                                  height: 200,
                                  child: PageView(
                                      children: listing.imageUrls
                                          .map((image) =>
                                              ListingImage(source: image))
                                          .toList())),
                            Text(
                                '${listing.imageUrls.length} ảnh · vuốt để xem'),
                            const SizedBox(height: 12),
                            Text(listing.propertyName),
                            Text(
                                '${listing.publicAddress}, ${listing.district}, ${listing.city}'),
                            Text(
                                '${formatCurrencyVnd(listing.monthlyRent)}/tháng · ${formatArea(listing.areaSqm)}'),
                            Text('Cọc: ${formatCurrencyVnd(listing.deposit)}'),
                            Text(
                                'Điện: ${formatCurrencyVnd(listing.electricityPrice)}/kWh'),
                            Text(
                                'Nước: ${formatCurrencyVnd(listing.waterPrice)}/m³'),
                            Text(
                                'Dịch vụ: ${formatCurrencyVnd(listing.serviceFee)}/tháng'),
                            const SizedBox(height: 12),
                            Text(listing.description),
                            const SizedBox(height: 12),
                            Text(listing.amenities.join(' · ')),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'))
                  ],
                ))));
  }

  Future<void> _edit([RoomListing? listing]) async {
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ListingFormScreen(listing: listing)));
    if (mounted) ref.invalidate(managedListingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    if (session?.user.id != _accountId ||
        session?.user.role != (widget.admin ? 'admin' : 'landlord')) {
      return const Scaffold(
          body: ListingMessage(
              title: 'Phiên quản lý đã thay đổi',
              message: 'Hãy mở lại trang từ tài khoản có quyền.'));
    }
    return ListingTheme(
        child: Scaffold(
      appBar: AppBar(
          title:
              Text(widget.admin ? 'Kiểm duyệt tin đăng' : 'Tin đăng của tôi'),
          actions: [
            if (widget.admin)
              IconButton(
                  tooltip: 'Quản lý trường học',
                  icon: const Icon(Icons.school_outlined),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const CampusManagementScreen()))),
            IconButton(
                tooltip:
                    widget.admin ? 'Phản hồi thử nghiệm' : 'Lịch xem phòng',
                icon: Icon(widget.admin
                    ? Icons.feedback_outlined
                    : Icons.event_available_outlined),
                onPressed: () => context.push(
                    widget.admin ? pilotFeedbackRoute : housingViewingsRoute)),
            if (widget.admin)
              IconButton(
                  tooltip: 'Báo cáo tin đăng',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const ListingReportsScreen()))),
            IconButton(
                tooltip: 'Xem trang khám phá',
                onPressed: () => context.push(exploreRoute),
                icon: const Icon(Icons.travel_explore)),
            if (!widget.admin)
              TextButton.icon(
                  onPressed: _busy ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo tin'))
          ]),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(managedListingsProvider(_query));
        },
        child: ListView(padding: const EdgeInsets.all(20), children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.rate_review_outlined),
            title: Text(
                widget.admin ? 'Kiểm duyệt đánh giá' : 'Đánh giá người thuê'),
            subtitle: Text(widget.admin
                ? 'Duyệt đánh giá và phản hồi chủ trọ.'
                : 'Xem đánh giá sau khi thuê và gửi phản hồi.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context
                .push(widget.admin ? adminReviewsRoute : landlordReviewsRoute),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              value: _status ?? 'ALL',
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: [
                'ALL',
                'DRAFT',
                'PENDING',
                'PUBLISHED',
                'REJECTED',
                'HIDDEN'
              ]
                  .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status == 'ALL'
                          ? 'Tất cả'
                          : listingStatusLabel(status))))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                        _status = value == 'ALL' ? null : value;
                        _page = 1;
                      })),
          const SizedBox(height: 20),
          ref.watch(managedListingsProvider(_query)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListingMessage(
                    title: 'Chưa tải được tin đăng',
                    message: listingError(error),
                    onRetry: () =>
                        ref.invalidate(managedListingsProvider(_query))),
                data: (page) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${page.total} tin đăng'),
                      const SizedBox(height: 12),
                      if (page.items.isEmpty)
                        const ListingMessage(
                            title: 'Chưa có tin đăng',
                            message:
                                'Tin tạo mới ở trạng thái nháp. Gửi duyệt để admin kiểm tra trước khi công khai.'),
                      for (final listing in page.items)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListingCard(
                                      listing: listing,
                                      onTap: () => _preview(listing)),
                                  const SizedBox(height: 8),
                                  Text(
                                      '${listingStatusLabel(listing.status)} · phiên bản ${listing.version}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  if (listing.reviewNote != null)
                                    Text('Phản hồi: ${listing.reviewNote}'),
                                  if (!widget.admin &&
                                      listing.status == 'PUBLISHED' &&
                                      !listing.availabilityFresh)
                                    const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                            'Tin chưa được xác nhận trong 14 ngày. Hãy kiểm tra và nhấn “Xác nhận còn phòng”.',
                                            style:
                                                TextStyle(color: kAirbnbRose))),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    if (!widget.admin)
                                      OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => Navigator.of(context)
                                                  .push(MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          ViewingSlotsScreen(
                                                              listingId:
                                                                  listing.id))),
                                          icon: const Icon(
                                              Icons.calendar_month_outlined),
                                          label: const Text('Khung giờ xem')),
                                    if (!widget.admin)
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _edit(listing),
                                          child: const Text('Chỉnh sửa')),
                                    if (!widget.admin &&
                                        ['DRAFT', 'REJECTED', 'HIDDEN']
                                            .contains(listing.status))
                                      FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () =>
                                                  _action(listing, 'submit'),
                                          child: const Text('Gửi duyệt')),
                                    if (!widget.admin &&
                                        listing.status != 'HIDDEN')
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _action(listing, 'hide'),
                                          child: const Text('Ẩn tin')),
                                    if (!widget.admin &&
                                        listing.status == 'PUBLISHED')
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _action(listing,
                                                  'confirm-availability'),
                                          child:
                                              const Text('Xác nhận còn phòng')),
                                    if (widget.admin &&
                                        listing.status == 'PUBLISHED')
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _verify(listing),
                                          child: const Text('Xác minh')),
                                    if (widget.admin &&
                                        listing.status == 'PENDING') ...[
                                      FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () =>
                                                  _action(listing, 'PUBLISH'),
                                          child: const Text('Duyệt')),
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () =>
                                                  _action(listing, 'REJECT'),
                                          child: const Text('Từ chối')),
                                    ],
                                    if (widget.admin &&
                                        listing.status == 'PUBLISHED')
                                      OutlinedButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _action(listing, 'HIDE'),
                                          child: const Text('Ẩn tin')),
                                  ]),
                                ])),
                      Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton(
                                onPressed: _page > 1 && !_busy
                                    ? () => setState(() => _page--)
                                    : null,
                                child: const Text('Trang trước')),
                            Text('Trang ${page.page}'),
                            OutlinedButton(
                                onPressed: page.hasNext && !_busy
                                    ? () => setState(() => _page++)
                                    : null,
                                child: const Text('Trang sau')),
                          ]),
                    ]),
              ),
        ]),
      ),
    ));
  }
}

class _ListingSessionBoundary extends ConsumerWidget {
  const _ListingSessionBoundary({required this.accountId, required this.child});
  final String? accountId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionIdentityProvider) == accountId) return child;
    return AlertDialog(
        title: const Text('Phiên quản lý đã thay đổi'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'))
        ]);
  }
}

class _ListingActionDialog extends ConsumerStatefulWidget {
  const _ListingActionDialog(
      {required this.title,
      required this.listingTitle,
      required this.needsReason,
      required this.publish,
      required this.accountId});
  final String title, listingTitle;
  final bool needsReason, publish;
  final String? accountId;
  @override
  ConsumerState<_ListingActionDialog> createState() =>
      _ListingActionDialogState();
}

class _ListingActionDialogState extends ConsumerState<_ListingActionDialog> {
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionIdentityProvider) != widget.accountId) {
      return AlertDialog(
          title: const Text('Phiên quản lý đã thay đổi'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'))
          ]);
    }
    return AlertDialog(
        title: Text(widget.title),
        content: Form(
            key: _form,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.listingTitle),
              const SizedBox(height: 12),
              if (widget.needsReason)
                TextFormField(
                    controller: _note,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Lý do'),
                    maxLines: 3,
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Cần nhập lý do' : null)
              else
                Text(widget.publish
                    ? 'Nội dung và ảnh này sẽ được công khai cho người tìm phòng.'
                    : 'Xác nhận thực hiện thao tác với tin này?'),
            ]))),
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
              child: const Text('Xác nhận')),
        ]);
  }
}

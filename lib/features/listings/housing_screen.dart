import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/format.dart';
import '../../models/housing.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../tenant_portal/tenant_portal_providers.dart';
import '../tenants/tenant_providers.dart';
import '../rooms/room_providers.dart';
import 'housing_dialog.dart';
import 'housing_providers.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';
import 'handover_screen.dart';
import 'viewing_slots_screen.dart';

enum HousingSection { favorites, viewings, notifications, feedback }

class HousingScreen extends ConsumerStatefulWidget {
  const HousingScreen({super.key, required this.section, this.viewingId});
  final HousingSection section;
  final String? viewingId;
  @override
  ConsumerState<HousingScreen> createState() => _HousingScreenState();
}

class _HousingScreenState extends ConsumerState<HousingScreen> {
  int _page = 1;
  bool _busy = false;

  String get _title => switch (widget.section) {
        HousingSection.favorites => 'Phòng yêu thích',
        HousingSection.viewings => 'Lịch xem phòng',
        HousingSection.notifications => 'Thông báo xem phòng',
        HousingSection.feedback => 'Phản hồi thử nghiệm',
      };

  void _invalidate() {
    ref.invalidate(savedRoomsProvider);
    ref.invalidate(savedRoomProvider);
    ref.invalidate(roomViewingsProvider);
    ref.invalidate(roomViewingProvider);
    ref.invalidate(housingNoticesProvider);
    ref.invalidate(pilotFeedbackProvider);
    ref.invalidate(viewingSlotsProvider);
  }

  Future<void> _mutate(Future<void> Function() action) async {
    final accountId = ref.read(sessionIdentityProvider);
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && ref.read(sessionIdentityProvider) == accountId) {
        _invalidate();
      }
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == accountId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewingAction(RoomViewing viewing, String? status) async {
    final accountId = ref.read(sessionIdentityProvider)!;
    final repository = ref.read(housingRepositoryProvider);
    final lease = status == null;
    final title = lease
        ? 'Tạo hợp đồng sau khi xem'
        : switch (status) {
            'CONFIRMED' => 'Xác nhận lịch xem',
            'CANCELLED' => 'Hủy lịch xem',
            _ => 'Đánh dấu đã xem phòng',
          };
    final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ListingTheme(
            child: HousingDialog(
                title: title,
                accountId: accountId,
                form: lease ? HousingForm.lease : HousingForm.viewingAction,
                requireNote: status == 'CANCELLED',
                description:
                    '${viewing.title}\nNgười xem: ${viewing.studentName}${status == 'CONFIRMED' ? '\nGhi rõ điểm hẹn và cách liên hệ. Không yêu cầu chuyển tiền để giữ lịch xem.' : ''}',
                rent: viewing.rent,
                deposit: viewing.deposit,
                onSubmit: (value) => lease
                    ? repository.createLease(
                        viewing, value.date, value.rent, value.deposit)
                    : repository.updateViewing(viewing, status, value.note))));
    if (!mounted || ref.read(sessionIdentityProvider) != accountId) return;
    _invalidate();
    if (result == true && lease) {
      ref.invalidate(publicListingsProvider);
      ref.invalidate(publicListingDetailProvider);
      ref.invalidate(managedListingsProvider);
      ref.invalidate(tenantPortalProfileProvider);
      ref.invalidate(tenantPortalLeasesProvider);
      ref.invalidate(tenantsProvider);
      ref.invalidate(roomsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Đã tạo hợp đồng và liên kết người thuê. Chưa ghi nhận thu cọc.')));
    }
  }

  Future<void> _reschedule(RoomViewing viewing) async {
    final accountId = ref.read(sessionIdentityProvider)!;
    final repository = ref.read(housingRepositoryProvider);
    await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ListingTheme(
            child: HousingDialog(
                title: 'Đổi lịch xem phòng',
                form: HousingForm.booking,
                accountId: accountId,
                listingId: viewing.listingId,
                description:
                    '${viewing.title}\nGiờ mới cần chủ trọ xác nhận lại. Lịch cũ chỉ được thay thế khi gửi thành công.',
                onSubmit: (value) => repository.reschedule(
                    viewing, value.date, value.note, value.slotId))));
    if (mounted && ref.read(sessionIdentityProvider) == accountId) {
      _invalidate();
    }
  }

  Widget _viewing(RoomViewing viewing, bool landlord) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(viewing.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
            '${formatDate(viewing.scheduledAt)} · ${TimeOfDay.fromDateTime(viewing.scheduledAt).format(context)} (giờ thiết bị)'),
        Text(viewing.address),
        Text(landlord
            ? 'Người xem: ${viewing.studentName}'
            : 'Chủ trọ: ${viewing.landlordName}'),
        const SizedBox(height: 8),
        Text(viewing.statusLabel,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        if (viewing.note.isNotEmpty) Text('Lời nhắn: ${viewing.note}'),
        if (viewing.responseNote.isNotEmpty)
          Text('Phản hồi: ${viewing.responseNote}'),
        if (viewing.status == 'CANCELLED' &&
            viewing.cancellationReason.isNotEmpty)
          Text('Lý do hủy: ${viewing.cancellationReason}'),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, children: [
          if (landlord && viewing.canCancel)
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) =>
                            ViewingSlotsScreen(listingId: viewing.listingId))),
                child: const Text('Mở khung giờ')),
          if (!landlord && viewing.canCancel)
            OutlinedButton(
                onPressed: _busy ? null : () => _reschedule(viewing),
                child: const Text('Đổi lịch')),
          if (viewing.leaseId != null)
            OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            HandoverScreen(leaseId: viewing.leaseId!))),
                child: const Text('Bàn giao & tiền cọc')),
          if (landlord && viewing.status == 'REQUESTED')
            FilledButton(
                onPressed:
                    _busy ? null : () => _viewingAction(viewing, 'CONFIRMED'),
                child: const Text('Xác nhận lịch')),
          if (landlord &&
              viewing.status == 'CONFIRMED' &&
              !viewing.scheduledAt.isAfter(DateTime.now()))
            FilledButton(
                onPressed:
                    _busy ? null : () => _viewingAction(viewing, 'COMPLETED'),
                child: const Text('Đã xem phòng')),
          if (landlord && viewing.status == 'COMPLETED')
            FilledButton(
                onPressed: _busy ? null : () => _viewingAction(viewing, null),
                child: const Text('Tạo hợp đồng')),
          if (viewing.canCancel)
            OutlinedButton(
                onPressed:
                    _busy ? null : () => _viewingAction(viewing, 'CANCELLED'),
                child: const Text('Hủy lịch')),
          if (!landlord && viewing.status == 'LEASED')
            FilledButton(
                onPressed: () {
                  ref.invalidate(tenantPortalProfileProvider);
                  ref.invalidate(tenantPortalDashboardProvider);
                  ref.invalidate(tenantPortalLeasesProvider);
                  ref.invalidate(tenantPortalInvoicesProvider);
                  context.push(tenantPortalRoute);
                },
                child: const Text('Phòng đang thuê')),
        ]),
      ]));

  Widget _paged<T>(AsyncValue<HousingPage<T>> value, Widget Function(T) tile,
          String empty) =>
      value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListingMessage(
            title: 'Chưa tải được dữ liệu',
            message: listingError(error),
            onRetry: _invalidate),
        data: (page) => RefreshIndicator(
            onRefresh: () async {
              _invalidate();
              try {
                switch (widget.section) {
                  case HousingSection.favorites:
                    await ref.read(savedRoomsProvider(_page).future);
                  case HousingSection.viewings:
                    await ref.read(roomViewingsProvider(_page).future);
                  case HousingSection.notifications:
                    await ref.read(housingNoticesProvider(_page).future);
                  case HousingSection.feedback:
                    await ref.read(pilotFeedbackProvider(_page).future);
                }
              } catch (_) {}
            },
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (page.items.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(empty)),
                  for (final item in page.items) ...[
                    tile(item),
                    const Divider(height: 1)
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                            onPressed: _page > 1 && !_busy
                                ? () => setState(() => _page--)
                                : null,
                            child: const Text('Trang trước')),
                        Text('Trang $_page · ${page.total} mục'),
                        OutlinedButton(
                            onPressed: page.hasNext && !_busy
                                ? () => setState(() => _page++)
                                : null,
                            child: const Text('Trang sau')),
                      ]),
                ])),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionIdentityProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _page = 1;
        });
      }
    });
    final landlord =
        ref.watch(sessionControllerProvider).session?.user.role == 'landlord';
    return ListingTheme(
        child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title:
              Text(_title, style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (widget.section == HousingSection.viewings)
              IconButton(
                  tooltip: 'Thông báo xem phòng',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push(housingNoticesRoute)),
            IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
                onPressed: _invalidate),
          ]),
      body: SafeArea(
          top: false,
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: switch (widget.section) {
                    HousingSection.favorites => _paged(
                        ref.watch(savedRoomsProvider(_page)),
                        (room) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            title: Text(room.title),
                            subtitle: Text(
                                '${room.address}\n${formatCurrencyVnd(room.rent)}/tháng${room.available ? '' : '\nTin đã ngừng nhận khách'}'),
                            onTap: room.available
                                ? () => context.push(publicListingPath(room.id))
                                : null,
                            trailing: IconButton(
                                tooltip: 'Bỏ lưu phòng',
                                icon: const Icon(Icons.favorite),
                                onPressed: _busy
                                    ? null
                                    : () {
                                        final repository =
                                            ref.read(housingRepositoryProvider);
                                        _mutate(() => repository.saveFavorite(
                                            room.id, false));
                                      })),
                        'Bạn chưa lưu phòng nào. Mở chi tiết phòng và chọn Lưu yêu thích.'),
                    HousingSection.viewings => widget.viewingId != null
                        ? ref
                            .watch(roomViewingProvider(widget.viewingId!))
                            .when(
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (error, _) => ListingMessage(
                                    title: 'Chưa tải được lịch xem',
                                    message: listingError(error),
                                    onRetry: _invalidate),
                                data: (viewing) => ListView(
                                    padding: const EdgeInsets.all(20),
                                    children: [_viewing(viewing, landlord)]))
                        : _paged(
                            ref.watch(roomViewingsProvider(_page)),
                            (viewing) => _viewing(viewing, landlord),
                            'Chưa có lịch xem. Chọn phòng phù hợp rồi đặt lịch xem phòng.'),
                    HousingSection.notifications => _paged(
                        ref.watch(housingNoticesProvider(_page)),
                        (notice) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            leading: Icon(notice.read
                                ? Icons.mark_email_read_outlined
                                : Icons.mark_email_unread_outlined),
                            title: Text(notice.message,
                                style: TextStyle(
                                    fontWeight: notice.read
                                        ? FontWeight.normal
                                        : FontWeight.w700)),
                            subtitle: Text(
                                '${formatDate(notice.createdAt)} · ${TimeOfDay.fromDateTime(notice.createdAt).format(context)}'),
                            onTap: _busy
                                ? null
                                : () async {
                                    final accountId =
                                        ref.read(sessionIdentityProvider);
                                    final repository =
                                        ref.read(housingRepositoryProvider);
                                    await _mutate(() =>
                                        repository.readNotification(notice.id));
                                    if (context.mounted &&
                                        ref.read(sessionIdentityProvider) ==
                                            accountId) {
                                      context.push(
                                          '$housingViewingsRoute?viewingId=${Uri.encodeComponent(notice.viewingId)}');
                                    }
                                  }),
                        'Chưa có thông báo. Kéo xuống để kiểm tra cập nhật lịch xem.'),
                    HousingSection.feedback => _paged(
                        ref.watch(pilotFeedbackProvider(_page)),
                        (feedback) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            title:
                                Text('${feedback.area} · ${feedback.rating}/5'),
                            subtitle:
                                Text('${feedback.stage}\n${feedback.detail}')),
                        'Chưa có phản hồi thử nghiệm.'),
                  }))),
    ));
  }
}

class RentalPilotScreen extends ConsumerWidget {
  const RentalPilotScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListingTheme(
          child: Scaffold(
        appBar: AppBar(title: const Text('Thử nghiệm khu vực nhỏ')),
        body: SafeArea(
            top: false,
            child: ref.watch(rentalPilotProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListingMessage(
                    title: 'Chưa tải được thử nghiệm',
                    message: listingError(error),
                    onRetry: () => ref.invalidate(rentalPilotProvider)),
                data: (pilot) =>
                    ListView(padding: const EdgeInsets.all(24), children: [
                      Text(
                          pilot.enabled
                              ? 'Khu vực: ${pilot.area}'
                              : 'Chưa mở thử nghiệm thực tế',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      const Text(
                          'Thử luồng tìm phòng, đặt lịch xem và quản lý sau khi thuê. Chỉ ghi phản hồi về trải nghiệm của bạn; không gửi căn cước, tài khoản ngân hàng hoặc thông tin riêng của người khác.'),
                      const SizedBox(height: 16),
                      Text(pilot.enabled
                          ? 'Phản hồi được lưu cùng tài khoản và chỉ quản trị viên xem được.'
                          : 'Quản trị viên cần cấu hình khu vực thử nghiệm và mời người tham gia trước khi mở thu thập phản hồi.'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          onPressed: !pilot.enabled
                              ? null
                              : () async {
                                  final accountId =
                                      ref.read(sessionIdentityProvider)!;
                                  final repository =
                                      ref.read(housingRepositoryProvider);
                                  final sent = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => ListingTheme(
                                          child: HousingDialog(
                                              title: 'Gửi phản hồi thử nghiệm',
                                              accountId: accountId,
                                              form: HousingForm.feedback,
                                              description:
                                                  'Khu vực ${pilot.area}',
                                              onSubmit: (value) =>
                                                  repository.feedback(
                                                      pilot,
                                                      value.stage,
                                                      value.rating,
                                                      value.note))));
                                  if (sent == true &&
                                      context.mounted &&
                                      ref.read(sessionIdentityProvider) ==
                                          accountId) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Đã lưu phản hồi. Cảm ơn bạn!')));
                                  }
                                },
                          icon: const Icon(Icons.feedback_outlined),
                          label: const Text('Gửi phản hồi')),
                    ]))),
      ));
}

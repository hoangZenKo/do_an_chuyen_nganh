import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room_listing.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'housing_dialog.dart';
import 'housing_providers.dart';
import 'listing_widgets.dart';

class ListingJourneyActions extends ConsumerStatefulWidget {
  const ListingJourneyActions({super.key, required this.listing});
  final RoomListing listing;
  @override
  ConsumerState<ListingJourneyActions> createState() =>
      _ListingJourneyActionsState();
}

class _ListingJourneyActionsState extends ConsumerState<ListingJourneyActions> {
  bool _busy = false;

  Future<void> _save(bool saved) async {
    final accountId = ref.read(sessionIdentityProvider);
    final repository = ref.read(housingRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repository.saveFavorite(widget.listing.id, saved);
      if (!mounted || ref.read(sessionIdentityProvider) != accountId) return;
      ref.invalidate(savedRoomProvider(widget.listing.id));
      ref.invalidate(savedRoomsProvider);
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == accountId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _book() async {
    final accountId = ref.read(sessionIdentityProvider)!;
    final repository = ref.read(housingRepositoryProvider);
    final sent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ListingTheme(
            child: HousingDialog(
                title: 'Đặt lịch xem phòng',
                accountId: accountId,
                form: HousingForm.booking,
                listingId: widget.listing.id,
                description:
                    '${widget.listing.title}\nGiờ hẹn theo múi giờ thiết bị. Chủ trọ nhận tên tài khoản và lời nhắn để xác nhận lịch. Chờ xác nhận trước khi tới; không chuyển tiền chỉ để giữ lịch xem.',
                onSubmit: (value) => repository.bookSlot(
                    widget.listing.id, value.date, value.note, value.slotId))));
    if (!mounted ||
        ref.read(sessionIdentityProvider) != accountId ||
        sent != true) {
      return;
    }
    ref.invalidate(roomViewingsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Đã gửi yêu cầu xem phòng.'),
        action: SnackBarAction(
            label: 'Xem lịch',
            onPressed: () => context.push(housingViewingsRoute))));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listing.isDemo) {
      return const Text(
          'Tin mẫu minh họa, không nhận lịch xem hoặc yêu cầu giữ chỗ.');
    }
    final session = ref.watch(sessionControllerProvider).session;
    if (session == null) {
      return FilledButton.icon(
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Đăng nhập để lưu phòng / đặt lịch'),
          onPressed: () => context.push(
              '$loginRoute?next=${Uri.encodeComponent(publicListingPath(widget.listing.id))}'));
    }
    if (session.user.role != 'tenant') return const SizedBox.shrink();
    final saved = ref.watch(savedRoomProvider(widget.listing.id));
    return Wrap(spacing: 12, runSpacing: 8, children: [
      saved.when(
          loading: () => const OutlinedButton(
              onPressed: null, child: Text('Đang tải yêu thích…')),
          error: (_, __) => OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(savedRoomProvider(widget.listing.id)),
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại yêu thích')),
          data: (value) => OutlinedButton.icon(
              onPressed: _busy ? null : () => _save(!value),
              icon: Icon(value ? Icons.favorite : Icons.favorite_border),
              label: Text(value ? 'Đã lưu vào tài khoản' : 'Lưu yêu thích'))),
      FilledButton.icon(
          onPressed: _book,
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Đặt lịch xem phòng')),
    ]);
  }
}

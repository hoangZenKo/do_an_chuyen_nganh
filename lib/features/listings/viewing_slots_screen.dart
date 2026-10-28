import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../auth/auth_providers.dart';
import 'housing_dialog.dart';
import 'housing_providers.dart';
import 'listing_widgets.dart';

class ViewingSlotsScreen extends ConsumerStatefulWidget {
  const ViewingSlotsScreen({super.key, required this.listingId});
  final String listingId;
  @override
  ConsumerState<ViewingSlotsScreen> createState() => _ViewingSlotsScreenState();
}

class _ViewingSlotsScreenState extends ConsumerState<ViewingSlotsScreen> {
  bool _busy = false;

  Future<void> _add() async {
    final accountId = ref.read(sessionIdentityProvider)!;
    final repository = ref.read(housingRepositoryProvider);
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ListingTheme(
            child: HousingDialog(
                title: 'Mở khung giờ xem phòng',
                form: HousingForm.booking,
                accountId: accountId,
                description:
                    'Mỗi lượt 30 phút, giờ theo thiết bị. Sau khi mở lịch, người xem chỉ đặt được các khung còn trống. Nếu xóa hết khung, tin sẽ chờ bạn mở lịch mới.',
                onSubmit: (value) =>
                    repository.addSlot(widget.listingId, value.date))));
    if (saved == true &&
        mounted &&
        ref.read(sessionIdentityProvider) == accountId) {
      ref.invalidate(viewingSlotsProvider(widget.listingId));
    }
  }

  Future<void> _remove(String id) async {
    final accountId = ref.read(sessionIdentityProvider);
    setState(() => _busy = true);
    try {
      await ref.read(housingRepositoryProvider).removeSlot(id);
      if (!mounted || ref.read(sessionIdentityProvider) != accountId) return;
      ref.invalidate(viewingSlotsProvider(widget.listingId));
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == accountId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListingTheme(
          child: Scaffold(
        appBar: AppBar(title: const Text('Khung giờ xem phòng')),
        body: SafeArea(
            top: false,
            child: ref.watch(viewingSlotsProvider(widget.listingId)).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListingMessage(
                      title: 'Chưa tải được lịch mở xem',
                      message: listingError(error),
                      onRetry: () => ref
                          .invalidate(viewingSlotsProvider(widget.listingId))),
                  data: (value) => RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(viewingSlotsProvider(widget.listingId));
                        await ref.read(
                            viewingSlotsProvider(widget.listingId).future);
                      },
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text('Khung giờ sắp tới',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            const Text(
                                'Mỗi khung nhận một lịch. Lịch đang chờ xác nhận cũng giữ chỗ để tránh trùng giờ cho bạn và sinh viên.'),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                                onPressed: _busy ? null : _add,
                                icon: const Icon(Icons.add),
                                label: const Text('Mở khung 30 phút')),
                            if (value.slots.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 28),
                                  child: Text(
                                      'Chưa có khung giờ sắp tới. Mở lịch để sinh viên chọn giờ phù hợp.')),
                            for (final slot in value.slots)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      '${formatDate(slot.startsAt)} · ${TimeOfDay.fromDateTime(slot.startsAt).format(context)} – ${TimeOfDay.fromDateTime(slot.endsAt).format(context)}'),
                                  subtitle: Text(slot.available
                                      ? 'Còn trống · giờ thiết bị'
                                      : 'Trùng lịch đang giữ chỗ'),
                                  trailing: IconButton(
                                      tooltip: 'Xóa khung giờ',
                                      onPressed: _busy || !slot.available
                                          ? null
                                          : () => _remove(slot.id),
                                      icon: const Icon(Icons.delete_outline))),
                          ])),
                )),
      ));
}

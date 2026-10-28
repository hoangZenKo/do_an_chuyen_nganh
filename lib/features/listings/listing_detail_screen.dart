import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/format.dart';
import '../auth/auth_navigation.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';
import '../auth/auth_providers.dart';
import 'student_listing_widgets.dart';
import 'listing_report_dialog.dart';
import 'listing_journey_actions.dart';
import 'review_composer.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListingTheme(
          child: Scaffold(
        appBar: AppBar(
            title: const Text('Chi tiết phòng'),
            leading: IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(exploreRoute))),
        body: ref.watch(publicListingDetailProvider(id)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ListingMessage(
                  title: 'Không thể mở tin đăng',
                  message: listingError(error),
                  onRetry: () =>
                      ref.invalidate(publicListingDetailProvider(id))),
              data: (listing) =>
                  ListView(padding: const EdgeInsets.all(20), children: [
                if (listing.imageUrls.isNotEmpty)
                  SizedBox(
                      height: 260,
                      child: PageView.builder(
                        itemCount: listing.imageUrls.length,
                        itemBuilder: (_, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(fit: StackFit.expand, children: [
                                  ListingImage(
                                      source: listing.imageUrls[index]),
                                  Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Text(
                                                  '${index + 1}/${listing.imageUrls.length}',
                                                  style: const TextStyle(
                                                      color: Colors.white))))),
                                ]))),
                      )),
                const SizedBox(height: 20),
                Text(listing.title,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                ListingJourneyActions(
                    key: ValueKey(ref.watch(sessionIdentityProvider)),
                    listing: listing),
                const SizedBox(height: 8),
                Text(listing.propertyName),
                Text(
                    '${listing.publicAddress}, ${listing.district}, ${listing.city}'),
                const SizedBox(height: 18),
                Text('${formatCurrencyVnd(listing.monthlyRent)}/tháng',
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB34200))),
                const SizedBox(height: 8),
                Text('Diện tích ${formatArea(listing.areaSqm)}'),
                const SizedBox(height: 24),
                const Text('Chi phí rõ ràng',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _fee('Tiền cọc', formatCurrencyVnd(listing.deposit)),
                _fee('Điện',
                    '${formatCurrencyVnd(listing.electricityPrice)}/kWh'),
                _fee('Nước', '${formatCurrencyVnd(listing.waterPrice)}/m³'),
                _fee('Dịch vụ',
                    '${formatCurrencyVnd(listing.serviceFee)}/tháng'),
                _fee(
                    'Gửi xe', '${formatCurrencyVnd(listing.parkingFee)}/tháng'),
                const SizedBox(height: 24),
                ListingCostPanel(listing: listing),
                const SizedBox(height: 24),
                ListingTrustPanel(listing: listing),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Báo cáo tin đăng'),
                  onPressed: () async {
                    final session = ref.read(sessionControllerProvider).session;
                    if (session == null) {
                      context.push(
                          '$loginRoute?next=${Uri.encodeComponent(publicListingPath(id))}');
                      return;
                    }
                    if (session.user.role != 'tenant') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Chức năng dành cho tài khoản sinh viên / người tìm phòng.')));
                      return;
                    }
                    final sent = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ListingTheme(
                            child: ListingReportDialog(listingId: id)));
                    if (sent == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Đã gửi báo cáo. Quản trị viên sẽ kiểm tra.')));
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text('Về căn phòng',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(listing.description),
                const SizedBox(height: 24),
                PublicReviewsSection(listingId: id),
                if (listing.amenities.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Tiện ích',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: listing.amenities
                          .map((item) => Chip(label: Text(item)))
                          .toList()),
                ],
                const SizedBox(height: 24),
                const Text(
                    'Thông tin do chủ trọ cung cấp. Giá và tình trạng phòng có thể thay đổi. Chờ chủ trọ xác nhận lịch trước khi tới xem; không chuyển tiền chỉ để giữ lịch.'),
              ]),
            ),
      ));

  Widget _fee(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 20,
          runSpacing: 4,
          children: [
            Text(title),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700))
          ]));
}

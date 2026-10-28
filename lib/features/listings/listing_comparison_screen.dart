import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../../models/room_listing.dart';
import '../../models/student_discovery.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';
import 'student_listing_widgets.dart';

class ListingComparisonScreen extends ConsumerStatefulWidget {
  const ListingComparisonScreen({super.key});
  @override
  ConsumerState<ListingComparisonScreen> createState() =>
      _ListingComparisonScreenState();
}

class _ListingComparisonScreenState
    extends ConsumerState<ListingComparisonScreen> {
  LivingCostEstimate? _estimate = const LivingCostEstimate();
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(listingComparisonProvider);
    final current = [
      for (final listing in selected)
        ref.watch(publicListingDetailProvider(listing.id))
    ];
    final fresh = [
      for (final listing in current)
        listing.isLoading || listing.hasError ? null : listing.valueOrNull
    ];
    return ListingTheme(
        child: Scaffold(
      appBar: AppBar(title: const Text('So sánh phòng'), actions: [
        IconButton(
            tooltip: 'Cập nhật thông tin',
            onPressed: () {
              for (final listing in selected) {
                ref.invalidate(publicListingDetailProvider(listing.id));
              }
            },
            icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Chọn tối đa 3 phòng. Chi phí sử dụng cùng một mức điện, nước để dễ so sánh.'),
        const SizedBox(height: 16),
        CostInputs(onChanged: (value) => setState(() => _estimate = value)),
        const SizedBox(height: 16),
        if (selected.isEmpty)
          const ListingMessage(
              title: 'Chưa chọn phòng',
              message: 'Quay lại Khám phá để chọn phòng so sánh.')
        else ...[
          const Text('Vuốt ngang để xem đầy đủ các phòng.'),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 100,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 110,
                columns: [
                  const DataColumn(label: Text('Tiêu chí')),
                  for (final listing in selected)
                    DataColumn(
                        label: SizedBox(
                            width: 170,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(listing.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  TextButton(
                                      onPressed: () => ref
                                          .read(listingComparisonProvider
                                              .notifier)
                                          .toggle(listing),
                                      child: const Text('Bỏ chọn')),
                                ])))
                ],
                rows: [
                  DataRow(cells: [
                    const DataCell(Text('Trạng thái')),
                    for (final listing in current)
                      DataCell(SizedBox(
                          width: 170,
                          child: listing.when(
                            loading: () => const Text('Đang cập nhật…'),
                            error: (error, _) => const Text(
                                'Tin không còn hiển thị hoặc chưa tải được. Hãy bỏ chọn và thử lại.'),
                            data: (_) => const Text('Thông tin từ hệ thống'),
                          )))
                  ]),
                  _row('Khu vực', fresh,
                      (listing) => '${listing.district}, ${listing.city}'),
                  DataRow(cells: [
                    const DataCell(SizedBox(
                        width: 130,
                        child: Text('Đến trường\n(đường chim bay lúc chọn)'))),
                    for (final listing in selected)
                      DataCell(Text(listing.distanceKm == null
                          ? 'Chưa lọc theo trường'
                          : '${listing.distanceKm!.toStringAsFixed(1)} km')),
                  ]),
                  _row('Diện tích', fresh,
                      (listing) => formatArea(listing.areaSqm)),
                  _row('Tiền phòng / tháng', fresh,
                      (listing) => formatCurrencyVnd(listing.monthlyRent)),
                  _row('Tiền cọc', fresh,
                      (listing) => formatCurrencyVnd(listing.deposit)),
                  _row('Dịch vụ / tháng', fresh,
                      (listing) => formatCurrencyVnd(listing.serviceFee)),
                  _row('Gửi xe / tháng', fresh,
                      (listing) => formatCurrencyVnd(listing.parkingFee)),
                  _row('Điện / kWh', fresh,
                      (listing) => formatCurrencyVnd(listing.electricityPrice)),
                  _row('Nước / m³', fresh,
                      (listing) => formatCurrencyVnd(listing.waterPrice)),
                  _row(
                      'Dự kiến / tháng',
                      fresh,
                      (listing) => _estimate == null
                          ? 'Kiểm tra mức sử dụng'
                          : formatCurrencyVnd(_estimate!.monthly(listing))),
                  _row(
                      'Chia đều / người',
                      fresh,
                      (listing) => _estimate == null
                          ? '—'
                          : formatCurrencyVnd(_estimate!.perPerson(listing))),
                  _row(
                      'Cọc + tháng đầu dự kiến',
                      fresh,
                      (listing) => _estimate == null
                          ? '—'
                          : formatCurrencyVnd(_estimate!.moveIn(listing))),
                  _row('Tiện ích', fresh,
                      (listing) => listing.amenities.join(' · ')),
                  _row(
                      'Kiểm tra thực tế',
                      fresh,
                      (listing) => listing.inspectedAt == null
                          ? 'Chưa kiểm tra'
                          : formatDate(listing.inspectedAt)),
                ],
              )),
          const SizedBox(height: 16),
          const Text(
              'Số tiền là ước tính, không phải hóa đơn hay số tiền bắt buộc trả trước. Chưa gồm các phí chưa kê khai và mua sắm. Cần hỏi rõ Internet có nằm trong phí dịch vụ không.'),
        ],
      ]),
    ));
  }

  DataRow _row(String label, List<RoomListing?> listings,
          String Function(RoomListing) value) =>
      DataRow(cells: [
        DataCell(SizedBox(width: 130, child: Text(label))),
        for (final listing in listings)
          DataCell(SizedBox(
              width: 170,
              child: Text(listing == null ? '—' : value(listing),
                  maxLines: 4, overflow: TextOverflow.ellipsis))),
      ]);
}

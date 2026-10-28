import 'package:flutter/material.dart';
import '../../core/utils/format.dart';
import '../../models/room_listing.dart';
import '../../models/student_discovery.dart';
import 'listing_widgets.dart';

class CostInputs extends StatefulWidget {
  const CostInputs({super.key, required this.onChanged});
  final ValueChanged<LivingCostEstimate?> onChanged;
  @override
  State<CostInputs> createState() => _CostInputsState();
}

class _CostInputsState extends State<CostInputs> {
  final _form = GlobalKey<FormState>();
  final _values = ['50', '3', '1'];
  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          for (var index = 0; index < _values.length; index++)
            SizedBox(
                width: 145,
                child: TextFormField(
                  initialValue: _values[index],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: [
                    'Điện (kWh/phòng)',
                    'Nước (m³/phòng)',
                    'Số người ở'
                  ][index]),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    final number = int.tryParse(value ?? '');
                    if (number == null ||
                        number < (index == 2 ? 1 : 0) ||
                        number > (index == 2 ? 20 : 10000)) {
                      return 'Nhập số hợp lệ';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _values[index] = value;
                    widget.onChanged(_form.currentState!.validate()
                        ? LivingCostEstimate(
                            electricityKwh: int.parse(_values[0]),
                            waterM3: int.parse(_values[1]),
                            people: int.parse(_values[2]),
                          )
                        : null);
                  },
                )),
        ]),
      );
}

class ListingCostPanel extends StatefulWidget {
  const ListingCostPanel({super.key, required this.listing});
  final RoomListing listing;
  @override
  State<ListingCostPanel> createState() => _ListingCostPanelState();
}

class _ListingCostPanelState extends State<ListingCostPanel> {
  LivingCostEstimate? _estimate = const LivingCostEstimate();
  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final estimate = _estimate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ngân sách ở trọ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text(
          'Điều chỉnh mức dùng điện, nước cho cả phòng. Chia đều chỉ là dự tính, không phải hóa đơn.'),
      const SizedBox(height: 16),
      CostInputs(onChanged: (value) => setState(() => _estimate = value)),
      const SizedBox(height: 12),
      if (estimate != null) ...[
        _costRow('Tiền phòng', listing.monthlyRent),
        _costRow(
            'Điện dự kiến', listing.electricityPrice * estimate.electricityKwh),
        _costRow('Nước dự kiến', listing.waterPrice * estimate.waterM3),
        _costRow('Dịch vụ cố định', listing.serviceFee),
        _costRow('Gửi xe đã kê khai', listing.parkingFee),
        const Divider(),
        _costRow('Tổng dự kiến / tháng', estimate.monthly(listing),
            strong: true),
        _costRow('Chia đều / người / tháng', estimate.perPerson(listing)),
        _costRow('Tiền cọc', listing.deposit),
        _costRow('Ngân sách cọc + tháng đầu', estimate.moveIn(listing),
            strong: true),
      ],
      const SizedBox(height: 8),
      const Text(
          'Ước tính theo đơn giá tin đăng, chưa gồm phí chưa kê khai, mua sắm hoặc chuyển nhà. Hỏi rõ Internet đã nằm trong phí dịch vụ chưa. Ngân sách tháng đầu không phải yêu cầu chuyển tiền hay lịch thu tiền của chủ trọ.',
          style: TextStyle(fontSize: 12, color: kAirbnbMuted)),
    ]);
  }

  Widget _costRow(String label, int value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(label),
              Text(formatCurrencyVnd(value),
                  style: TextStyle(
                      fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
            ]),
      );
}

class ListingTrustPanel extends StatelessWidget {
  const ListingTrustPanel({super.key, required this.listing});
  final RoomListing listing;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Thông tin & độ tin cậy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (listing.isDemo)
          const Text(
              'DỮ LIỆU MẪU · Tin, địa chỉ và tọa độ chỉ dùng thử giao diện.',
              style:
                  TextStyle(color: kAirbnbRose, fontWeight: FontWeight.w700)),
        _status(
            Icons.fact_check_outlined,
            listing.publishedAt == null
                ? 'Chưa có thông tin duyệt nội dung'
                : 'Nội dung được duyệt: ${formatDate(listing.publishedAt)}'),
        _status(
            Icons.verified_user_outlined,
            listing.landlordVerifiedAt == null
                ? 'Chưa xác thực danh tính chủ trọ'
                : 'Đã xác thực chủ trọ: ${formatDate(listing.landlordVerifiedAt)}'),
        _status(
            Icons.home_work_outlined,
            listing.inspectedAt == null
                ? 'Chưa kiểm tra phòng thực tế'
                : 'Đã kiểm tra phòng: ${formatDate(listing.inspectedAt)}'),
        _status(
            Icons.update,
            listing.availabilityConfirmedAt == null
                ? 'Chưa có xác nhận gần đây về phòng trống'
                : 'Chủ trọ xác nhận còn phòng: ${formatDate(listing.availabilityConfirmedAt)}'),
        if (!listing.availabilityFresh)
          const Text(
              'Thông tin phòng trống có thể đã cũ. Hãy liên hệ xác nhận trước khi đi xem hoặc chuyển cọc.',
              style:
                  TextStyle(color: kAirbnbRose, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Duyệt nội dung không phải bảo đảm an toàn giao dịch. Hãy xem phòng, kiểm tra người cho thuê và thỏa thuận rõ các khoản phí trước khi chuyển cọc.',
            style: TextStyle(fontSize: 12, color: kAirbnbMuted)),
      ]);
  Widget _status(IconData icon, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ]));
}

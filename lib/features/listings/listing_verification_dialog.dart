import 'package:flutter/material.dart';
import '../../models/room_listing.dart';

typedef ListingVerification = ({
  bool landlordVerified,
  bool roomInspected,
  String note
});

class ListingVerificationDialog extends StatefulWidget {
  const ListingVerificationDialog({super.key, required this.listing});
  final RoomListing listing;
  @override
  State<ListingVerificationDialog> createState() =>
      _ListingVerificationDialogState();
}

class _ListingVerificationDialogState extends State<ListingVerificationDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  late bool _landlordVerified;
  late bool _roomInspected;
  @override
  void initState() {
    super.initState();
    _landlordVerified = widget.listing.landlordVerifiedAt != null;
    _roomInspected = widget.listing.inspectedAt != null;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Ghi nhận xác minh'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Chỉ đánh dấu khi đã kiểm tra và có căn cứ. Không ghi giấy tờ định danh hoặc thông tin nhạy cảm vào ghi chú.'),
                      CheckboxListTile(
                          value: _landlordVerified,
                          onChanged: (value) =>
                              setState(() => _landlordVerified = value!),
                          title: const Text('Đã xác thực danh tính chủ trọ')),
                      CheckboxListTile(
                          value: _roomInspected,
                          onChanged: (value) =>
                              setState(() => _roomInspected = value!),
                          title: const Text('Đã kiểm tra phòng thực tế')),
                      TextFormField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                            labelText: 'Căn cứ và cách kiểm tra'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Nhập ít nhất 10 ký tự'
                            : null,
                      ),
                    ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, (
                    landlordVerified: _landlordVerified,
                    roomInspected: _roomInspected,
                    note: _note.text.trim()
                  ));
                }
              },
              child: const Text('Lưu xác minh')),
        ],
      );
}

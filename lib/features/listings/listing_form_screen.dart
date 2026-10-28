import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room.dart';
import '../../models/room_listing.dart';
import '../auth/auth_providers.dart';
import '../rooms/room_providers.dart';
import '../tenant_portal/tenant_portal_providers.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';

typedef ListingRoomOption = ({Room room, String propertyName});
final listingRoomOptionsProvider =
    FutureProvider.autoDispose<List<ListingRoomOption>>((ref) async {
  final repository = ref.watch(roomRepositoryProvider);
  final properties = await repository.properties();
  final groups = await Future.wait(properties.map((property) async =>
      (await repository.roomsOf(property.id))
          .where((room) => room.isActive && room.status == RoomStatus.vacant)
          .map((room) => (room: room, propertyName: property.name))
          .toList()));
  return groups.expand((group) => group).toList();
});

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.listing});
  final RoomListing? listing;
  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  String? _roomId;
  String? _accountId;
  bool _busy = false;
  String? _error;

  static const _labels = {
    'title': 'Tiêu đề',
    'description': 'Mô tả công khai',
    'city': 'Tỉnh / Thành phố',
    'district': 'Quận / Huyện',
    'publicAddress': 'Địa chỉ được phép công khai',
    'monthlyRent': 'Giá thuê (đ/tháng)',
    'deposit': 'Tiền cọc (đ)',
    'electricityPrice': 'Điện (đ/kWh)',
    'waterPrice': 'Nước (đ/m³)',
    'serviceFee': 'Dịch vụ cố định (đ/tháng)',
    'parkingFee': 'Gửi xe (đ/tháng, 0 nếu đã gồm trong dịch vụ)',
    'latitude': 'Vĩ độ (tùy chọn, cần nhập cùng kinh độ)',
    'longitude': 'Kinh độ (tùy chọn, cần nhập cùng vĩ độ)',
    'areaSqm': 'Diện tích (m²)',
    'amenities': 'Tiện ích (mỗi dòng một mục)',
    'imageUrls': 'Ảnh (mỗi dòng một URL ảnh)',
  };
  static const _numbers = [
    'monthlyRent',
    'deposit',
    'electricityPrice',
    'waterPrice',
    'serviceFee',
    'parkingFee',
    'areaSqm'
  ];

  @override
  void initState() {
    super.initState();
    _accountId = ref.read(sessionIdentityProvider);
    _roomId = widget.listing?.roomId;
    final content = widget.listing?.content ?? {};
    for (final key in _labels.keys) {
      final value = content[key];
      _fields[key] = TextEditingController(
          text: value is List
              ? value.join('\n')
              : value?.toString() ??
                  (_numbers.contains(key) &&
                          key != 'monthlyRent' &&
                          key != 'areaSqm'
                      ? '0'
                      : ''));
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String key) => _fields[key]!
      .text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']);
    if (result == null || !mounted) return;
    if (ref.read(sessionIdentityProvider) != _accountId) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (result.files.single.size > 8 * 1024 * 1024) {
      setState(() => _error = 'Ảnh không được vượt quá 8 MB.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(uploadApiProvider)
          .uploadFile(path, publicListing: true);
      if (!mounted) return;
      _fields['imageUrls']!.text = {..._lines('imageUrls'), url}.join('\n');
    } catch (error) {
      if (mounted) setState(() => _error = listingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_roomId == null) {
      setState(() => _error = 'Hãy chọn phòng.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final content = <String, dynamic>{};
    for (final key in _labels.keys) {
      if (key == 'latitude' || key == 'longitude') {
        final coordinate = double.tryParse(_fields[key]!.text.trim());
        content[key] = coordinate;
        continue;
      }
      content[key] = ['amenities', 'imageUrls'].contains(key)
          ? _lines(key)
          : key == 'areaSqm'
              ? double.parse(_fields[key]!.text)
              : _numbers.contains(key)
                  ? int.parse(_fields[key]!.text)
                  : _fields[key]!.text.trim();
    }
    if (widget.listing == null) {
      content['roomId'] = _roomId;
    } else {
      content['version'] = widget.listing!.version;
    }
    try {
      await ref
          .read(managedListingsRepositoryProvider)
          .save(content, id: widget.listing?.id);
      ref.invalidate(managedListingsProvider);
      ref.invalidate(publicListingsProvider);
      ref.invalidate(publicListingDetailProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = listingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    if (session?.user.id != _accountId || session?.user.role != 'landlord') {
      return const Scaffold(
          body: ListingMessage(
              title: 'Phiên quản lý đã thay đổi',
              message: 'Hãy mở lại trang từ tài khoản chủ trọ.'));
    }
    return ListingTheme(
        child: Scaffold(
      appBar: AppBar(
          title: Text(widget.listing == null
              ? 'Tạo tin phòng trọ'
              : 'Chỉnh sửa tin đăng')),
      body: Form(
          key: _form,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        'Chỉ nhập nội dung được phép công khai. Chỉnh sửa tin đã duyệt sẽ đưa tin về bản nháp và cần duyệt lại.'),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red))),
                    if (widget.listing == null)
                      ref.watch(listingRoomOptionsProvider).when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) => ListingMessage(
                                title: 'Chưa tải được phòng',
                                message: listingError(error),
                                onRetry: () =>
                                    ref.invalidate(listingRoomOptionsProvider)),
                            data: (options) => options.isEmpty
                                ? const Text(
                                    'Chưa có phòng trống. Hãy tạo phòng hoặc cập nhật tình trạng phòng trước.')
                                : DropdownButtonFormField<String>(
                                    value: _roomId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Chọn phòng trống'),
                                    items: options
                                        .map((option) => DropdownMenuItem(
                                            value: option.room.id,
                                            child: Text(
                                                '${option.propertyName} · ${option.room.name}',
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                        .toList(),
                                    validator: (value) => value == null
                                        ? 'Chọn phòng cần đăng tin'
                                        : null,
                                    onChanged: _busy
                                        ? null
                                        : (value) => setState(() {
                                              _roomId = value;
                                              final option = options.firstWhere(
                                                  (option) =>
                                                      option.room.id == value);
                                              _fields['title']!.text =
                                                  '${option.room.name} · ${option.propertyName}';
                                              _fields['monthlyRent']!.text =
                                                  option.room.basePrice
                                                      .toString();
                                              _fields['areaSqm']!.text = option
                                                      .room.areaSqm
                                                      ?.toString() ??
                                                  '';
                                              _fields['amenities']!.text =
                                                  option.room.amenities
                                                      .join('\n');
                                              final image =
                                                  option.room.imageUrl;
                                              if (image != null &&
                                                  (image.startsWith('http') ||
                                                      image.startsWith(
                                                          '/uploads/'))) {
                                                _fields['imageUrls']!.text =
                                                    image;
                                              }
                                            })),
                          ),
                    const SizedBox(height: 18),
                    for (final entry in _labels.entries) ...[
                      TextFormField(
                          controller: _fields[entry.key],
                          enabled: !_busy,
                          decoration: InputDecoration(
                              labelText: entry.value, alignLabelWithHint: true),
                          keyboardType: _numbers.contains(entry.key)
                              ? const TextInputType.numberWithOptions(
                                  decimal: true)
                              : TextInputType.multiline,
                          maxLines: ['description', 'imageUrls', 'amenities']
                                  .contains(entry.key)
                              ? 4
                              : 1,
                          maxLength: switch (entry.key) {
                            'title' => 160,
                            'description' => 10000,
                            'city' || 'district' => 100,
                            'publicAddress' => 250,
                            _ => null
                          },
                          validator: (value) {
                            final text = value!.trim();
                            if (entry.key == 'latitude' ||
                                entry.key == 'longitude') {
                              final other = _fields[entry.key == 'latitude'
                                      ? 'longitude'
                                      : 'latitude']!
                                  .text
                                  .trim();
                              if (text.isEmpty && other.isEmpty) return null;
                              final coordinate = double.tryParse(text);
                              final limit = entry.key == 'latitude' ? 90 : 180;
                              if (coordinate == null ||
                                  !coordinate.isFinite ||
                                  coordinate.abs() > limit) {
                                return 'Nhập tọa độ hợp lệ và đủ cả hai trường';
                              }
                              return null;
                            }
                            if (entry.key == 'amenities') {
                              if (_lines(entry.key).length > 30 ||
                                  _lines(entry.key)
                                      .any((line) => line.length > 80)) {
                                return 'Tối đa 30 tiện ích, mỗi mục 80 ký tự';
                              }
                              return null;
                            }
                            if (text.isEmpty) return 'Vui lòng nhập thông tin';
                            if (entry.key == 'title' && text.length < 5) {
                              return 'Tiêu đề tối thiểu 5 ký tự';
                            }
                            if (entry.key == 'description' &&
                                text.length < 20) {
                              return 'Mô tả tối thiểu 20 ký tự';
                            }
                            if (entry.key == 'imageUrls') {
                              final images = _lines(entry.key);
                              if (images.length > 12) return 'Tối đa 12 ảnh';
                              final pattern = RegExp(
                                  r'^(https?://[^\s]+|/uploads/[a-zA-Z0-9_-]+\.(?:jpe?g|png|webp|heic|heif))$',
                                  caseSensitive: false);
                              if (images.any((image) =>
                                  image.length > 2048 ||
                                  !pattern.hasMatch(image))) {
                                return 'Nhập URL ảnh http/https hoặc tải ảnh lên';
                              }
                            }
                            if (_numbers.contains(entry.key)) {
                              final number = num.tryParse(text);
                              if (number == null ||
                                  !number.isFinite ||
                                  number < 0 ||
                                  number > 2147483647) {
                                return 'Nhập số hợp lệ không âm';
                              }
                              if (entry.key != 'areaSqm' &&
                                  int.tryParse(text) == null) {
                                return 'Nhập số nguyên';
                              }
                              if (['monthlyRent', 'areaSqm']
                                      .contains(entry.key) &&
                                  number <= 0) {
                                return 'Giá trị phải lớn hơn 0';
                              }
                              if (entry.key == 'areaSqm' && number > 100000) {
                                return 'Diện tích quá lớn';
                              }
                            }
                            return null;
                          }),
                      if (entry.key == 'imageUrls')
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _upload,
                            icon: const Icon(Icons.upload),
                            label: const Text('Tải ảnh từ thiết bị')),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Đang xử lý...' : 'Lưu bản nháp')),
                    const SizedBox(height: 20),
                  ]))),
    ));
  }
}

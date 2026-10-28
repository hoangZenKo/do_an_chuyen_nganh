import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../../core/network/api_failure.dart';
import '../../models/housing.dart';
import '../auth/auth_providers.dart';
import '../rooms/widgets/room_image.dart';
import '../tenant_portal/tenant_portal_providers.dart';
import 'housing_providers.dart';
import 'listing_widgets.dart';

class HandoverScreen extends ConsumerStatefulWidget {
  const HandoverScreen({super.key, required this.leaseId});
  final String leaseId;
  @override
  ConsumerState<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends ConsumerState<HandoverScreen> {
  final _form = GlobalKey<FormState>();
  final _electricity = TextEditingController();
  final _water = TextEditingController();
  final _condition = TextEditingController();
  List<String> _images = [];
  int? _loadedVersion;
  String? _loadedAccount;
  bool _busy = false, _acknowledged = false;
  String? _error;

  @override
  void dispose() {
    _electricity.dispose();
    _water.dispose();
    _condition.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action,
      {bool refresh = true}) async {
    final accountId = ref.read(sessionIdentityProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted || ref.read(sessionIdentityProvider) != accountId) return;
      if (refresh) {
        ref.invalidate(leaseHandoverProvider(widget.leaseId));
        ref.invalidate(housingNoticesProvider);
        ref.invalidate(tenantPortalLeasesProvider);
        ref.invalidate(tenantPortalProfileProvider);
        ref.invalidate(tenantPortalDashboardProvider);
      }
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == accountId) {
        setState(() => _error = listingError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final accountId = ref.read(sessionIdentityProvider);
    final uploader = ref.read(uploadApiProvider);
    await _run(() async {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']);
      if (!mounted ||
          ref.read(sessionIdentityProvider) != accountId ||
          result == null) {
        return;
      }
      final file = result.files.single;
      if (file.size > 8 * 1024 * 1024) {
        throw const ApiFailure(message: 'Ảnh phải nhỏ hơn hoặc bằng 8 MB.');
      }
      if (file.path == null) {
        throw const ApiFailure(
            message: 'Không đọc được ảnh. Hãy chọn lại file.');
      }
      final url = await uploader.uploadFile(file.path!);
      if (mounted && ref.read(sessionIdentityProvider) == accountId) {
        setState(() => _images.add(url));
      }
    }, refresh: false);
  }

  Widget _meter(TextEditingController controller, String label) =>
      TextFormField(
          controller: controller,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            return number == null || number < 0 || number > 2147483647
                ? 'Nhập chỉ số nguyên không âm hợp lệ.'
                : null;
          });

  Widget _detail(HandoverDetail detail, bool landlord, String? accountId) {
    final handover = detail.handover;
    final version = handover?.version ?? 0;
    if (_loadedVersion != version || _loadedAccount != accountId) {
      _loadedVersion = version;
      _loadedAccount = accountId;
      _electricity.text = handover?.electricity.toString() ?? '';
      _water.text = handover?.water.toString() ?? '';
      _condition.text = handover?.condition ?? '';
      _images = [...?handover?.images];
      _acknowledged = false;
    }
    final editable = landlord && detail.active && handover?.acceptedAt == null;
    final ready = detail.active && !detail.startDate.isAfter(DateTime.now());
    final repository = ref.read(housingRepositoryProvider);
    const labels = {
      'agreed': 'Cọc thỏa thuận',
      'collected': 'Đã thu',
      'refunded': 'Đã hoàn',
      'deducted': 'Đã khấu trừ',
      'adjustment': 'Điều chỉnh',
      'balance': 'Cọc đang giữ'
    };
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Phòng ${detail.roomName}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      Text(detail.propertyName),
      const SizedBox(height: 24),
      Text(
          handover?.acceptedAt != null
              ? 'Đã xác nhận nhận phòng · ${formatDate(handover!.acceptedAt)}'
              : handover != null
                  ? 'Chờ người thuê kiểm tra và xác nhận'
                  : 'Chưa có biên bản bàn giao',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      if (!detail.active)
        const Text('Hợp đồng đã kết thúc. Biên bản chỉ để tra cứu.'),
      if (editable)
        Form(
            key: _form,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Ghi lại chỉ số thực tế khi bàn giao. Không tự đánh dấu người thuê đã nhận phòng.'),
              const SizedBox(height: 16),
              _meter(_electricity, 'Chỉ số điện ban đầu (kWh)'),
              const SizedBox(height: 12),
              _meter(_water, 'Chỉ số nước ban đầu (m³)'),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _condition,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                      labelText: 'Hiện trạng, tài sản và hư hỏng có sẵn'),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Mô tả hiện trạng ít nhất 10 ký tự.'
                      : null),
            ]))
      else if (handover != null) ...[
        Text('Điện ban đầu: ${handover.electricity} kWh'),
        Text('Nước ban đầu: ${handover.water} m³'),
        const SizedBox(height: 12),
        SelectableText(handover.condition),
      ] else
        const Text(
            'Chủ trọ cần lập biên bản trước khi bạn xác nhận nhận phòng.'),
      const SizedBox(height: 16),
      const Text('Ảnh hiện trạng (riêng tư)',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (_images.isEmpty) const Text('Chưa đính kèm ảnh.'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final url in _images)
          SizedBox(
              width: 136,
              child: Column(children: [
                SizedBox(
                    height: 110,
                    width: 136,
                    child: Semantics(
                        button: true,
                        label: 'Phóng to ảnh hiện trạng',
                        child: GestureDetector(
                            onTap: () => showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          SizedBox(
                                              height: MediaQuery.sizeOf(context)
                                                      .height *
                                                  0.6,
                                              child: InteractiveViewer(
                                                  child: RoomImageView(
                                                      source: url,
                                                      fit: BoxFit.contain,
                                                      placeholder: const Center(
                                                          child: Text(
                                                              'Chưa tải được ảnh'))))),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Đóng ảnh')),
                                        ]))),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: RoomImageView(
                                    source: url,
                                    placeholder: const Center(
                                        child: Text('Chưa tải được ảnh'))))))),
                if (editable)
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _images.remove(url)),
                      child: const Text('Bỏ ảnh')),
              ]))
      ]),
      if (editable) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: _busy || _images.length >= 12 ? null : _upload,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('Thêm ảnh · ${_images.length}/12')),
        const Text(
            'Ảnh tối đa 8 MB. Chỉ hai bên hợp đồng được xem; không dùng ảnh công khai của tin đăng.'),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy
                ? null
                : () {
                    if (_form.currentState!.validate()) {
                      _run(() => repository.saveHandover(
                          widget.leaseId,
                          version,
                          int.parse(_electricity.text),
                          int.parse(_water.text),
                          _condition.text,
                          [..._images]));
                    }
                  },
            child: const Text('Lưu biên bản bàn giao')),
      ],
      if (!landlord &&
          handover != null &&
          handover.acceptedAt == null &&
          detail.active) ...[
        const SizedBox(height: 16),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acknowledged,
            onChanged: _busy || !ready
                ? null
                : (value) => setState(() => _acknowledged = value ?? false),
            title: const Text(
                'Tôi đã thực sự nhận phòng, kiểm tra hiện trạng, ảnh và chỉ số điện nước.')),
        if (!ready)
          Text('Có thể xác nhận từ ngày ${formatDate(detail.startDate)}.'),
        FilledButton(
            onPressed: _busy || !_acknowledged || !ready
                ? null
                : () => _run(
                    () => repository.acceptHandover(widget.leaseId, version)),
            child: const Text('Xác nhận đã nhận phòng')),
      ],
      const SizedBox(height: 28),
      const Text('Đối chiếu tiền cọc',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      for (final entry in labels.entries)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(spacing: 12, children: [
              Text('${entry.value}:'),
              Text(formatCurrencyVnd(detail.deposit[entry.key] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700))
            ])),
      const Text(
          'Cọc thỏa thuận không đồng nghĩa đã thu. Số liệu dựa trên sổ giao dịch; bàn giao không tự tạo giao dịch tiền cọc.'),
      if (_busy)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator()),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final accountId = ref.watch(sessionIdentityProvider);
    final landlord =
        ref.watch(sessionControllerProvider).session?.user.role == 'landlord';
    return ListingTheme(
        child: Scaffold(
            appBar: AppBar(title: const Text('Bàn giao & tiền cọc'), actions: [
              IconButton(
                  tooltip: 'Tải lại biên bản',
                  onPressed: _busy
                      ? null
                      : () =>
                          ref.invalidate(leaseHandoverProvider(widget.leaseId)),
                  icon: const Icon(Icons.refresh))
            ]),
            body: SafeArea(
                top: false,
                child: ref.watch(leaseHandoverProvider(widget.leaseId)).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ListingMessage(
                        title: 'Chưa tải được biên bản',
                        message: listingError(error),
                        onRetry: () => ref
                            .invalidate(leaseHandoverProvider(widget.leaseId))),
                    data: (detail) => _detail(detail, landlord, accountId)))));
  }
}

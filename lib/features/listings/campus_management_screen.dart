import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/student_discovery.dart';
import '../auth/auth_providers.dart';
import 'discovery_tools.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';

class CampusManagementScreen extends ConsumerWidget {
  const CampusManagementScreen({super.key});
  Future<void> _edit(BuildContext context, WidgetRef ref,
      [SchoolCampus? campus]) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => _CampusForm(campus: campus)));
    if (changed == true) {
      ref.invalidate(adminCampusesProvider);
      ref.invalidate(schoolCampusesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAdminProvider)) {
      return const Scaffold(
          body: Center(child: Text('Chỉ quản trị viên được quản lý trường.')));
    }
    return ListingTheme(
        child: Scaffold(
      appBar: AppBar(title: const Text('Trường & cơ sở học')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Thêm cơ sở')),
      body: ref.watch(adminCampusesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(adminCampusesProvider),
                    child: const Text('Tải lại danh sách'))),
            data: (items) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const Text(
                      'Nhập địa chỉ và tọa độ từ nguồn tin cậy. Dữ liệu mẫu được gắn nhãn riêng; tắt cơ sở sẽ ẩn khỏi bộ lọc công khai.'),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Text(
                        'Chưa có cơ sở. Thêm trường để sinh viên lọc phòng gần nơi học.'),
                  for (final campus in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(campus.isActive
                          ? Icons.school_outlined
                          : Icons.visibility_off_outlined),
                      title: Text(campus.label),
                      subtitle: Text(
                          '${campus.address}\n${campus.latitude}, ${campus.longitude} · ${campus.isActive ? 'Đang hiển thị' : 'Đã tắt'}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(context, ref, campus),
                    ),
                ]),
          ),
    ));
  }
}

class _CampusForm extends ConsumerStatefulWidget {
  const _CampusForm({this.campus});
  final SchoolCampus? campus;
  @override
  ConsumerState<_CampusForm> createState() => _CampusFormState();
}

class _CampusFormState extends ConsumerState<_CampusForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.campus?.name);
  late final _campus = TextEditingController(text: widget.campus?.campus);
  late final _city = TextEditingController(text: widget.campus?.city);
  late final _address = TextEditingController(text: widget.campus?.address);
  late final _latitude =
      TextEditingController(text: widget.campus?.latitude.toString());
  late final _longitude =
      TextEditingController(text: widget.campus?.longitude.toString());
  late final _source = TextEditingController(text: widget.campus?.sourceUrl);
  late bool _active = widget.campus?.isActive ?? true;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final field in [
      _name,
      _campus,
      _city,
      _address,
      _latitude,
      _longitude,
      _source
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(discoveryToolsProvider).campus({
        'name': _name.text.trim(),
        'campus': _campus.text.trim(),
        'city': _city.text.trim(),
        'address': _address.text.trim(),
        'latitude': double.parse(_latitude.text),
        'longitude': double.parse(_longitude.text),
        'sourceUrl': _source.text.trim().isEmpty ? null : _source.text.trim(),
        if (widget.campus != null) 'isActive': _active,
      }, widget.campus?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Chưa lưu được. Kiểm tra thông tin và kết nối rồi thử lại.';
        });
      }
    }
  }

  Widget _text(
          TextEditingController field, String label, int maxLength) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: field,
              enabled: !_busy,
              maxLength: maxLength,
              decoration: InputDecoration(labelText: label),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Nhập ít nhất 2 ký tự'
                  : null));
  Widget _coordinate(TextEditingController field, String label, double max) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: field,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(labelText: label),
              validator: (value) {
                final number = double.tryParse(value ?? '');
                return number == null || !number.isFinite || number.abs() > max
                    ? 'Nhập tọa độ từ -$max đến $max'
                    : null;
              }));
  @override
  Widget build(BuildContext context) => ListingTheme(
          child: Scaffold(
        appBar: AppBar(
            title: Text(
                widget.campus == null ? 'Thêm cơ sở học' : 'Chỉnh sửa cơ sở')),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: kAirbnbRose)),
              if (widget.campus?.isDemo == true)
                const Text(
                    'Cơ sở dữ liệu mẫu. Chỉnh sửa không chuyển thành trường đã xác thực.'),
              _text(_name, 'Tên trường', 160),
              _text(_campus, 'Tên cơ sở', 160),
              _text(_city, 'Tỉnh / Thành phố', 100),
              _text(_address, 'Địa chỉ', 250),
              _coordinate(_latitude, 'Vĩ độ', 90),
              _coordinate(_longitude, 'Kinh độ', 180),
              TextFormField(
                  controller: _source,
                  enabled: !_busy,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                      labelText: 'Nguồn tham khảo HTTPS (không bắt buộc)'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final uri = Uri.tryParse(value.trim());
                    return uri?.scheme == 'https' &&
                            (uri?.host.contains('.') ?? false)
                        ? null
                        : 'Nhập URL HTTPS hợp lệ';
                  }),
              if (widget.campus != null)
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _active = value),
                    title: const Text('Hiển thị trong bộ lọc')),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Đang lưu…' : 'Lưu cơ sở')),
            ])),
      ));
}

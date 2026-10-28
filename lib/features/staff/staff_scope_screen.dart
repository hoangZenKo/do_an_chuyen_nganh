import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../models/staff.dart';
import '../rooms/room_providers.dart';
import '../tenants/widgets/form_widgets.dart';
import 'staff_providers.dart';

class StaffScopeScreen extends ConsumerStatefulWidget {
  const StaffScopeScreen({super.key, required this.staff});

  final StaffMember staff;

  @override
  ConsumerState<StaffScopeScreen> createState() => _StaffScopeScreenState();
}

class _StaffScopeScreenState extends ConsumerState<StaffScopeScreen> {
  late final _propertyIds = widget.staff.propertyIds.toSet();
  bool _saving = false;
  bool _simulating = false;
  String? _error;
  String? _propertyId;
  String _permission = 'billing.view';
  Map<String, dynamic>? _simulation;

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(staffApiProvider).update(widget.staff.id, {
        'propertyIds': _propertyIds.toList()..sort(),
      });
      ref.invalidate(staffMembersProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiFailure
            ? error.message : 'Không lưu được phạm vi. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _simulate() async {
    if (_propertyId == null) {
      return;
    }
    setState(() { _simulating = true; _error = null; _simulation = null; });
    try {
      final result = await ref.read(staffApiProvider).simulate(widget.staff.id,
          propertyId: _propertyId!, permission: _permission);
      if (mounted) {
        setState(() => _simulation = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiFailure
            ? error.message : 'Không kiểm tra được quyền. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Phạm vi nhân viên')),
      body: SafeArea(
        child: properties.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: TextButton.icon(
            onPressed: () => ref.invalidate(propertiesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại danh sách khu trọ'),
          )),
          data: (items) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.staff.fullName, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Chỉ các khu trọ được chọn mới hiển thị cho nhân viên. '
                  'Bỏ chọn tất cả để thu hồi toàn bộ phạm vi.',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 20),
              if (items.isEmpty) const Text('Chưa có khu trọ. Tạo khu trọ trước khi cấp phạm vi.'),
              for (final property in items)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(property.name),
                  subtitle: property.address.isEmpty ? null : Text(property.address),
                  value: _propertyIds.contains(property.id),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _saving ? null : (value) => setState(() {
                    if (value == true) { _propertyIds.add(property.id); }
                    else { _propertyIds.remove(property.id); }
                    _simulation = null;
                  }),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                FormErrorBanner(message: _error!),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Đang lưu…' : 'Lưu phạm vi'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text('Kiểm tra quyền đã lưu', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Kiểm tra phạm vi và quyền module trên máy chủ. '
                  'Thay đổi chưa lưu không được áp dụng; quy tắc từng thao tác vẫn có hiệu lực.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _propertyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Khu trọ cần kiểm tra'),
                items: items.map((property) => DropdownMenuItem(
                  value: property.id, child: Text(property.name),
                )).toList(),
                onChanged: _simulating ? null : (value) => setState(() {
                  _propertyId = value; _simulation = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _permission,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Quyền module'),
                items: const {
                  'property.view': 'Xem khu trọ',
                  'room.manage': 'Quản lý phòng',
                  'tenant.view': 'Xem người thuê',
                  'lease.manage': 'Quản lý hợp đồng',
                  'billing.view': 'Xem hóa đơn',
                  'billing.record_payment': 'Ghi nhận thanh toán',
                  'maintenance.manage': 'Quản lý bảo trì',
                  'report.export': 'Xuất báo cáo',
                }.entries.map((entry) => DropdownMenuItem(
                  value: entry.key, child: Text(entry.value),
                )).toList(),
                onChanged: _simulating ? null : (value) => setState(() {
                  _permission = value ?? _permission; _simulation = null;
                }),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _propertyId == null || _simulating || _saving ? null : _simulate,
                icon: const Icon(Icons.policy_outlined),
                label: Text(_simulating ? 'Đang kiểm tra…' : 'Kiểm tra quyền'),
              ),
              if (_simulation != null) ...[
                const SizedBox(height: 12),
                Text(_simulation!['allowed'] == true
                    ? 'Được phép trong phạm vi và module đã chọn.'
                    : 'Không được phép.', style: textTheme.titleSmall),
                for (final reason in _simulation!['reasons'] as List? ?? const [])
                  Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(_reasonLabel(reason.toString()))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _reasonLabel(String reason) => switch (reason) {
    'STAFF_INACTIVE' => 'Tài khoản nhân viên đã bị khóa.',
    'MODULE_PERMISSION_MISSING' => 'Chưa được cấp quyền module này.',
    'PROPERTY_NOT_ASSIGNED' => 'Chưa được cấp khu trọ này.',
    'PROPERTY_ARCHIVED' => 'Khu trọ đã lưu trữ.',
    'LANDLORD_ONLY_ACTION' => 'Thao tác chỉ dành cho chủ trọ.',
    _ => reason,
  };
}

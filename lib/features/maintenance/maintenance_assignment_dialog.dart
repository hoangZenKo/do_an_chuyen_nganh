import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../models/maintenance.dart';
import '../auth/auth_providers.dart';
import 'maintenance_providers.dart';

class MaintenanceAssignmentDialog extends ConsumerStatefulWidget {
  const MaintenanceAssignmentDialog({super.key, required this.ticket});
  final MaintenanceTicket ticket;

  @override
  ConsumerState<MaintenanceAssignmentDialog> createState() =>
      _MaintenanceAssignmentDialogState();
}

class _MaintenanceAssignmentDialogState
    extends ConsumerState<MaintenanceAssignmentDialog> {
  late final _assignees = ref.read(maintenanceApiProvider).assignees(
      propertyId: widget.ticket.propertyId);
  late final _owner = ref.read(sessionIdentityProvider);
  late String _assigneeId = widget.ticket.assigneeStaffProfileId ?? '';
  late DateTime? _deadline = widget.ticket.dueAt;
  bool _deadlineChanged = false;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _owner != ref.read(sessionIdentityProvider)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _assignees;
      await ref.read(maintenanceApiProvider).update(widget.ticket.id, {
        'assigneeStaffProfileId': _assigneeId.isEmpty ? null : _assigneeId,
        if (_deadlineChanged) 'dueAt': _deadline!.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ref.invalidate(maintenanceListProvider);
      ref.invalidate(maintenanceDetailProvider(widget.ticket.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ApiFailure
              ? error.message
              : 'Chưa thể lưu phân công. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _owner == ref.watch(sessionIdentityProvider);
    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Giao việc & hạn xử lý'),
          content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _assignees,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                              'Chưa tải được nhân viên. Đóng và thử lại.');
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final rows = snapshot.data!;
                        final inactiveAssignee = _assigneeId.isNotEmpty &&
                            !rows.any((row) => row['id'] == _assigneeId);
                        return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(widget.ticket.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                  value: _assigneeId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Nhân viên phụ trách'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '',
                                        child: Text('Chưa giao nhân viên')),
                                    if (inactiveAssignee)
                                      DropdownMenuItem(
                                          value: _assigneeId,
                                          enabled: false,
                                          child: Text(
                                              '${widget.ticket.assigneeName ?? 'Nhân viên cũ'} (không hoạt động)')),
                                    for (final row in rows)
                                      DropdownMenuItem(
                                          value: row['id'] as String,
                                          child:
                                              Text(row['fullName'] as String)),
                                  ],
                                  onChanged: _saving || !active
                                      ? null
                                      : (value) => setState(
                                          () => _assigneeId = value ?? '')),
                              const SizedBox(height: 16),
                              Text(
                                  'Hạn xử lý: ${formatDate(_deadline?.toLocal())}'),
                              const Text(
                                  'SLA mặc định: khẩn cấp 4 giờ, vừa 48 giờ, thấp 7 ngày.'),
                              TextButton.icon(
                                  onPressed: _saving || !active
                                      ? null
                                      : () async {
                                          final now = DateTime.now();
                                          final latest = DateTime(now.year + 5);
                                          var initial = _deadline != null &&
                                                  _deadline!.isAfter(now)
                                              ? _deadline!.toLocal()
                                              : now;
                                          if (initial.isAfter(latest)) {
                                            initial = latest;
                                          }
                                          final value = await showDatePicker(
                                              context: context,
                                              initialDate: initial,
                                              firstDate: now,
                                              lastDate: latest);
                                          if (value != null && mounted) {
                                            setState(() {
                                              _deadline = DateTime(
                                                  value.year,
                                                  value.month,
                                                  value.day,
                                                  23,
                                                  59);
                                              _deadlineChanged = true;
                                            });
                                          }
                                        },
                                  icon: const Icon(Icons.event),
                                  label: const Text('Đổi ngày hoàn thành')),
                              if (_error != null)
                                Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              if (!active)
                                const Text(
                                    'Phiên làm việc đã thay đổi. Vui lòng đóng cửa sổ.'),
                            ]);
                      }))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: _saving || !active ? null : _save,
                child: Text(_saving ? 'Đang lưu...' : 'Lưu phân công'))
          ],
        ));
  }
}

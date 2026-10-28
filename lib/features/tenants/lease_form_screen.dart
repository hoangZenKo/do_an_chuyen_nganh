import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../models/room.dart';
import '../rooms/room_providers.dart';
import 'tenant_providers.dart';

/// Create an active lease assigning the tenant to a vacant room.
class LeaseFormScreen extends ConsumerStatefulWidget {
  const LeaseFormScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<LeaseFormScreen> createState() => _LeaseFormScreenState();
}

class _LeaseFormScreenState extends ConsumerState<LeaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  Room? _selectedRoom;
  DateTime _startDate = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _rent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  void _onRoomSelected(Room? room) {
    setState(() {
      _selectedRoom = room;
      if (room != null && _rent.text.trim().isEmpty) {
        _rent.text = room.basePrice.toString();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_selectedRoom == null) {
      setState(() => _error = 'Vui lòng chọn phòng.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(leaseFormControllerProvider.notifier).create(
            roomId: _selectedRoom!.id,
            tenantId: widget.tenantId,
            monthlyRent: int.tryParse(_rent.text.trim()) ?? 0,
            deposit: int.tryParse(_deposit.text.trim()) ?? 0,
            startDate: _startDate,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is ApiFailure
            ? error.message
            : 'Không thể tạo hợp đồng. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyId = ref.watch(selectedPropertyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo hợp đồng')),
      body: propertyId == null
          ? Center(
              child: Text('Chưa chọn khu trọ. Hãy mở tab Phòng trước.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : _buildForm(ref, propertyId),
    );
  }

  Widget _buildForm(WidgetRef ref, String propertyId) {
    final roomsAsync = ref.watch(roomsProvider(propertyId));
    final colors = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    );
    final inputStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );

    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('$error',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
      data: (rooms) {
        final vacant =
            rooms.where((r) => r.status == RoomStatus.vacant).toList();
        if (vacant.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Không có phòng trống để tạo hợp đồng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: colors.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                fontSize: 13, color: colors.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Chọn phòng trống', style: labelStyle),
              const SizedBox(height: 6),
              _RoomDropdown(
                rooms: vacant,
                value: _selectedRoom,
                onChanged: _onRoomSelected,
              ),
              const SizedBox(height: 16),
              Text('Giá thuê (đ)', style: labelStyle),
              const SizedBox(height: 6),
              TextFormField(
                controller: _rent,
                style: inputStyle,
                decoration: const InputDecoration(
                  hintText: '3500000',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final value = int.tryParse((v ?? '').trim());
                  if (value == null || value <= 0) {
                    return 'Nhập giá thuê hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Tiền cọc (đ)', style: labelStyle),
              const SizedBox(height: 6),
              TextFormField(
                controller: _deposit,
                style: inputStyle,
                decoration: const InputDecoration(
                  hintText: '3500000',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              Text('Ngày bắt đầu', style: labelStyle),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(formatDate(_startDate), style: inputStyle),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: colors.onPrimary),
                        )
                      : const Text('Tạo hợp đồng',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomDropdown extends StatelessWidget {
  const _RoomDropdown({
    required this.rooms,
    required this.value,
    required this.onChanged,
  });

  final List<Room> rooms;
  final Room? value;
  final ValueChanged<Room?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      isEmpty: value == null,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Room>(
          value: value,
          isExpanded: true,
          dropdownColor: theme.colorScheme.surface,
          iconEnabledColor: theme.colorScheme.onSurfaceVariant,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          hint: Text('Chọn phòng',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          items: rooms
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(
                    '${r.name} · ${formatCurrencyVnd(r.basePrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

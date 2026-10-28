import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/room.dart';
import '../rooms/room_providers.dart';
import 'tenant_providers.dart';
import 'widgets/form_widgets.dart';

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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Tạo hợp đồng')),
      body: propertyId == null
          ? const Center(
              child: Text('Chưa chọn khu trọ. Hãy mở tab Phòng trước.',
                  style: TextStyle(color: Color(0xFF6B7280))),
            )
          : _buildForm(ref, propertyId),
    );
  }

  Widget _buildForm(WidgetRef ref, String propertyId) {
    final roomsAsync = ref.watch(roomsProvider(propertyId));

    return roomsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (error, _) => Center(
        child: Text('$error', style: const TextStyle(color: Color(0xFF6B7280))),
      ),
      data: (rooms) {
        final vacant =
            rooms.where((r) => r.status == RoomStatus.vacant).toList();
        if (vacant.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Không có phòng trống để tạo hợp đồng.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280)),
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
                FormErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              const FieldLabel('Chọn phòng trống'),
              const SizedBox(height: 6),
              _RoomDropdown(
                rooms: vacant,
                value: _selectedRoom,
                onChanged: _onRoomSelected,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _rent,
                label: 'Giá thuê (đ)',
                hint: '3500000',
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
              AppTextField(
                controller: _deposit,
                label: 'Tiền cọc (đ)',
                hint: '3500000',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              const FieldLabel('Ngày bắt đầu'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDate(_startDate),
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF111827))),
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SubmitButton(
                label: 'Tạo hợp đồng',
                loading: _submitting,
                onPressed: _submit,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Room>(
          value: value,
          isExpanded: true,
          hint: const Text('Chọn phòng'),
          items: rooms
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text('${r.name} · ${formatCurrencyVnd(r.basePrice)}'),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

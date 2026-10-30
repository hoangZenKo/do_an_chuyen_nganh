import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../models/maintenance.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../rooms/room_providers.dart';
import '../tenants/widgets/form_widgets.dart';
import 'maintenance_providers.dart';

class MaintenanceFormScreen extends ConsumerStatefulWidget {
  const MaintenanceFormScreen({super.key, this.ticketId});

  final String? ticketId;

  @override
  ConsumerState<MaintenanceFormScreen> createState() =>
      _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends ConsumerState<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _reportedAt = TextEditingController(text: _todayIsoDate());
  final _estimatedCost = TextEditingController();
  final _actualCost = TextEditingController();
  final _note = TextEditingController();
  MaintenanceStatus _status = MaintenanceStatus.open;
  MaintenancePriority _priority = MaintenancePriority.medium;
  String? _propertyId;
  String? _roomId;
  bool _hydrated = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reportedAt.dispose();
    _estimatedCost.dispose();
    _actualCost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final formState = ref.watch(maintenanceFormControllerProvider);
    final AsyncValue<MaintenanceTicket?> ticketAsync;
    if (widget.ticketId == null) {
      ticketAsync = const AsyncValue<MaintenanceTicket?>.data(null);
    } else {
      ticketAsync = ref
          .watch(maintenanceDetailProvider(widget.ticketId!))
          .whenData((value) {
        _hydrate(value);
        return value;
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.ticketId == null ? 'Báo sửa chữa' : 'Sửa yêu cầu'),
      ),
      body: ticketAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary),
        ),
        error: (error, _) => Center(child: Text('$error')),
        data: (_) => propertiesAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary),
          ),
          error: (error, _) => Center(child: Text('$error')),
          data: (properties) {
            if (properties.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Chưa có khu trọ để tạo yêu cầu sửa chữa.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (_propertyId == null ||
                !properties.any((property) => property.id == _propertyId)) {
              final selected = ref.read(selectedPropertyProvider);
              _propertyId =
                  properties.any((property) => property.id == selected)
                      ? selected
                      : properties.first.id;
            }

            final selectedProperty = properties.firstWhere(
              (property) => property.id == _propertyId,
              orElse: () => properties.first,
            );
            final roomsAsync = ref.watch(roomsProvider(selectedProperty.id));

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (formState.hasError) ...[
                    FormErrorBanner(message: _friendlyError(formState.error)),
                    const SizedBox(height: 12),
                  ],
                  const FieldLabel('Khu trọ'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Property>(
                    value: selectedProperty,
                    items: properties
                        .map(
                          (property) => DropdownMenuItem(
                            value: property,
                            child: Text(property.name),
                          ),
                        )
                        .toList(),
                    onChanged: (property) {
                      setState(() {
                        _propertyId = property?.id;
                        _roomId = null;
                      });
                    },
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  roomsAsync.when(
                    loading: () => LinearProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    error: (error, _) => Text('$error'),
                    data: (rooms) {
                      if (rooms.isNotEmpty &&
                          !rooms.any((room) => room.id == _roomId)) {
                        _roomId = rooms.first.id;
                      }
                      return _RoomDropdown(
                        rooms: rooms,
                        roomId: _roomId,
                        onChanged: (id) => setState(() => _roomId = id),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Mức độ'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<MaintenancePriority>(
                    value: _priority,
                    items: MaintenancePriority.values
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _priority = value ?? MaintenancePriority.medium,
                    ),
                    decoration: _inputDecoration(),
                  ),
                  if (widget.ticketId != null) ...[
                    const SizedBox(height: 16),
                    const FieldLabel('Trạng thái'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<MaintenanceStatus>(
                      value: _status,
                      items: MaintenanceStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _status = value ?? MaintenanceStatus.open,
                      ),
                      decoration: _inputDecoration(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _title,
                    label: 'Tiêu đề',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _description,
                    label: 'Mô tả sự cố',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _reportedAt,
                    label: 'Ngày báo',
                    hint: '2026-08-10',
                    validator: _requiredDate,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _estimatedCost,
                    label: 'Chi phí dự kiến (đ)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validCost,
                  ),
                  if (widget.ticketId != null) ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _actualCost,
                      label: 'Chi phí thực tế (đ)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validCost,
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _note,
                    label: 'Ghi chú nội bộ',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SubmitButton(
                    label: widget.ticketId == null ? 'Tạo yêu cầu' : 'Lưu',
                    loading: formState.isLoading,
                    onPressed: () => _submit(selectedProperty.id),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _hydrate(MaintenanceTicket ticket) {
    if (_hydrated) return;
    _hydrated = true;
    _propertyId = ticket.propertyId;
    _roomId = ticket.roomId;
    _status = ticket.status;
    _priority = ticket.priority;
    _title.text = ticket.title;
    _description.text = ticket.description ?? '';
    _reportedAt.text = _isoDate(ticket.reportedAt ?? DateTime.now());
    _estimatedCost.text = ticket.estimatedCost?.toString() ?? '';
    _actualCost.text = ticket.actualCost?.toString() ?? '';
    _note.text = ticket.note ?? '';
  }

  Future<void> _submit(String selectedPropertyId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_roomId == null || _roomId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn phòng cần sửa chữa.')),
      );
      return;
    }
    try {
      await ref.read(maintenanceFormControllerProvider.notifier).submit(
            ticketId: widget.ticketId,
            propertyId: _propertyId ?? selectedPropertyId,
            roomId: _roomId!,
            status: _status,
            priority: _priority,
            title: _title.text,
            description: _description.text,
            reportedAt: _reportedAt.text,
            estimatedCost: _intOrNull(_estimatedCost.text),
            actualCost: _intOrNull(_actualCost.text),
            note: _note.text,
          );
      if (mounted) context.pop();
    } catch (_) {
      // Provider state renders the error banner.
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bắt buộc.';
    return null;
  }

  String? _requiredDate(String? value) {
    final text = value?.trim() ?? '';
    final parsed = DateTime.tryParse(text);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        parsed == null ||
        _isoDate(parsed) != text) {
      return 'Nhập ngày hợp lệ (YYYY-MM-DD).';
    }
    return null;
  }

  String? _validCost(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = int.tryParse(value.trim());
    return amount == null || amount < 0 || amount > 2147483647
        ? 'Chi phí phải từ 0 đến 2.147.483.647 đ.'
        : null;
  }

  String _friendlyError(Object? error) {
    if (error is ApiFailure) {
      return switch (error.code) {
        'PROPERTY_NOT_FOUND' => 'Không tìm thấy khu trọ.',
        'ROOM_NOT_FOUND' => 'Không tìm thấy phòng trong khu trọ này.',
        'INVALID_MAINTENANCE_STATUS' => 'Trạng thái không hợp lệ.',
        'INVALID_MAINTENANCE_PRIORITY' => 'Mức độ không hợp lệ.',
        'INVALID_MAINTENANCE_DATE' => 'Ngày không hợp lệ.',
        _ => error.message,
      };
    }
    return '$error';
  }

  static String _todayIsoDate() => _isoDate(DateTime.now());

  static String _isoDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _RoomDropdown extends StatelessWidget {
  const _RoomDropdown({
    required this.rooms,
    required this.roomId,
    required this.onChanged,
  });

  final List<Room> rooms;
  final String? roomId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Text(
        'Khu trọ này chưa có phòng để báo sửa chữa.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final currentRoomId =
        rooms.any((room) => room.id == roomId) ? roomId : rooms.first.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Phòng'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: currentRoomId,
          items: rooms
              .map(
                (room) => DropdownMenuItem(
                  value: room.id,
                  child: Text('Phòng ${room.name}'),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: _inputDecoration(),
        ),
      ],
    );
  }
}

int? _intOrNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

InputDecoration _inputDecoration() => const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

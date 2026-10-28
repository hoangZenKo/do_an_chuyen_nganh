import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../models/expense.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../rooms/room_providers.dart';
import '../tenants/widgets/form_widgets.dart';
import 'expense_providers.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expenseId});

  final String? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController(text: _todayIsoDate());
  final _note = TextEditingController();
  final _receiptUrl = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.repair;
  String? _propertyId;
  String? _roomId;
  bool _hydrated = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _date.dispose();
    _note.dispose();
    _receiptUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final formState = ref.watch(expenseFormControllerProvider);
    final AsyncValue<Expense?> expenseAsync;
    if (widget.expenseId == null) {
      expenseAsync = const AsyncValue<Expense?>.data(null);
    } else {
      expenseAsync =
          ref.watch(expenseDetailProvider(widget.expenseId!)).whenData((value) {
        _hydrate(value);
        return value;
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: Text(widget.expenseId == null ? 'Thêm chi phí' : 'Sửa chi phí'),
      ),
      body: expenseAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => Center(child: Text('$error')),
        data: (_) => propertiesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (error, _) => Center(child: Text('$error')),
          data: (properties) {
            if (properties.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Chưa có khu trọ để ghi nhận chi phí.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (_propertyId == null ||
                !properties.any((property) => property.id == _propertyId)) {
              _propertyId = properties.first.id;
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
                    loading: () => const LinearProgressIndicator(
                      color: AppTheme.primary,
                    ),
                    error: (error, _) => Text('$error'),
                    data: (rooms) => _RoomDropdown(
                      rooms: rooms,
                      roomId: _roomId,
                      onChanged: (id) => setState(() => _roomId = id),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Loại chi phí'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ExpenseCategory>(
                    value: _category,
                    items: ExpenseCategory.values
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _category = value ?? ExpenseCategory.other,
                    ),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _title,
                    label: 'Tiêu đề',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _amount,
                    label: 'Số tiền (đ)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _positiveInt,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _date,
                    label: 'Ngày chi',
                    hint: '2026-08-10',
                    validator: _requiredDate,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _receiptUrl,
                    label: 'Link biên lai',
                    hint: 'https://...',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _note,
                    label: 'Ghi chú',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SubmitButton(
                    label: widget.expenseId == null ? 'Thêm chi phí' : 'Lưu',
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

  void _hydrate(Expense expense) {
    if (_hydrated) return;
    _hydrated = true;
    _propertyId = expense.propertyId;
    _roomId = expense.roomId;
    _category = expense.category;
    _title.text = expense.title;
    _amount.text = expense.amount.toString();
    _date.text = _isoDate(expense.expenseDate ?? DateTime.now());
    _note.text = expense.note ?? '';
    _receiptUrl.text = expense.receiptUrl ?? '';
  }

  Future<void> _submit(String selectedPropertyId) async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(expenseFormControllerProvider.notifier).submit(
            expenseId: widget.expenseId,
            propertyId: _propertyId ?? selectedPropertyId,
            roomId: _roomId,
            category: _category,
            amount: int.parse(_amount.text.trim()),
            expenseDate: _date.text.trim(),
            title: _title.text,
            note: _note.text,
            receiptUrl: _receiptUrl.text,
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
    if (value == null || value.trim().isEmpty) return 'Nhập ngày hợp lệ.';
    return DateTime.tryParse(value.trim()) == null ? 'Nhập ngày hợp lệ.' : null;
  }

  String? _positiveInt(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Nhập số tiền hợp lệ.';
    return null;
  }

  String _friendlyError(Object? error) {
    if (error is ApiFailure) {
      return switch (error.code) {
        'PROPERTY_NOT_FOUND' => 'Không tìm thấy khu trọ.',
        'ROOM_NOT_FOUND' => 'Không tìm thấy phòng trong khu trọ này.',
        'INVALID_EXPENSE_CATEGORY' => 'Loại chi phí không hợp lệ.',
        'INVALID_EXPENSE_DATE' => 'Ngày chi không hợp lệ.',
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
    final currentRoomId =
        rooms.any((room) => room.id == roomId) ? roomId : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Phòng'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          value: currentRoomId,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Chi phí chung của khu trọ'),
            ),
            ...rooms.map(
              (room) => DropdownMenuItem<String?>(
                value: room.id,
                child: Text('Phòng ${room.name}'),
              ),
            ),
          ],
          onChanged: onChanged,
          decoration: _inputDecoration(),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration() => InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E3348)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
      ),
    );

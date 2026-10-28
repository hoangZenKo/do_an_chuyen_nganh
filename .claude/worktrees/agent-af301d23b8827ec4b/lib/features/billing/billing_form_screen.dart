import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../tenants/widgets/form_widgets.dart';
import 'billing_providers.dart';
import 'widgets/meter_reading_fields.dart';

class BillingFormScreen extends ConsumerStatefulWidget {
  const BillingFormScreen({super.key});

  @override
  ConsumerState<BillingFormScreen> createState() => _BillingFormScreenState();
}

class _BillingFormScreenState extends ConsumerState<BillingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _month = TextEditingController(text: _defaultMonth());
  final _dueDate = TextEditingController();
  final _electricityPrevious = TextEditingController();
  final _electricityCurrent = TextEditingController();
  final _electricityUnit = TextEditingController();
  final _waterPrevious = TextEditingController();
  final _waterCurrent = TextEditingController();
  final _waterUnit = TextEditingController();
  final _otherAmount = TextEditingController(text: '0');
  final _note = TextEditingController();
  String? _selectedLeaseId;
  String? _lastPrefillKey;
  int _prefillToken = 0;
  MeterReading? _electricityBaseline;
  MeterReading? _waterBaseline;

  @override
  void initState() {
    super.initState();
    _month.addListener(_handleMonthChanged);
    for (final controller in [
      _electricityPrevious,
      _electricityCurrent,
      _electricityUnit,
      _waterPrevious,
      _waterCurrent,
      _waterUnit,
    ]) {
      controller.addListener(_refreshMeterSummary);
    }
  }

  @override
  void dispose() {
    _month.removeListener(_handleMonthChanged);
    for (final controller in [
      _electricityPrevious,
      _electricityCurrent,
      _electricityUnit,
      _waterPrevious,
      _waterCurrent,
      _waterUnit,
    ]) {
      controller.removeListener(_refreshMeterSummary);
    }
    _month.dispose();
    _dueDate.dispose();
    _electricityPrevious.dispose();
    _electricityCurrent.dispose();
    _electricityUnit.dispose();
    _waterPrevious.dispose();
    _waterCurrent.dispose();
    _waterUnit.dispose();
    _otherAmount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _refreshMeterSummary() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final leasesAsync = ref.watch(billingActiveLeasesProvider);
    final formState = ref.watch(billingFormControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Tạo hóa đơn')),
      body: leasesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => Center(child: Text('$error')),
        data: (leases) {
          if (leases.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Chưa có hợp đồng đang thuê để tạo hóa đơn.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (_selectedLeaseId == null ||
              !leases.any((lease) => lease.id == _selectedLeaseId)) {
            _selectedLeaseId = leases.first.id;
          }
          final selectedLease = leases.firstWhere(
            (lease) => lease.id == _selectedLeaseId,
            orElse: () => leases.first,
          );
          _prefillForCurrentLease(selectedLease);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (formState.hasError) ...[
                  FormErrorBanner(message: _friendlyError(formState.error)),
                  const SizedBox(height: 12),
                ],
                const FieldLabel('Hợp đồng'),
                const SizedBox(height: 6),
                DropdownButtonFormField<BillingLease>(
                  value: selectedLease,
                  items: leases
                      .map(
                        (lease) => DropdownMenuItem(
                          value: lease,
                          child: Text(
                            'Phòng ${lease.roomName} • ${lease.tenantName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (lease) {
                    setState(() => _selectedLeaseId = lease?.id);
                    if (lease != null) _prefillForCurrentLease(lease);
                  },
                  decoration: _inputDecoration(),
                ),
                if (selectedLease.fixedFeeAmount > 0) ...[
                  const SizedBox(height: 10),
                  _FixedFeeHint(lease: selectedLease),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  controller: _month,
                  label: 'Tháng hóa đơn',
                  hint: '2026-08-01',
                  validator: _requiredDate,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _dueDate,
                  label: 'Hạn thanh toán',
                  hint: '2026-08-10',
                  validator: _optionalDate,
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Chỉ số điện'),
                const SizedBox(height: 10),
                MeterReadingFields(
                  previous: _electricityPrevious,
                  current: _electricityCurrent,
                  unitPrice: _electricityUnit,
                  utilityType: UtilityType.electricity,
                  baseline: _electricityBaseline,
                  validator: (field) => meterValidator(
                    field,
                    _electricityPrevious,
                    _electricityCurrent,
                    _electricityUnit,
                  ),
                  summary: meterSummary(
                    _electricityPrevious,
                    _electricityCurrent,
                    _electricityUnit,
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Chỉ số nước'),
                const SizedBox(height: 10),
                MeterReadingFields(
                  previous: _waterPrevious,
                  current: _waterCurrent,
                  unitPrice: _waterUnit,
                  utilityType: UtilityType.water,
                  baseline: _waterBaseline,
                  validator: (field) => meterValidator(
                    field,
                    _waterPrevious,
                    _waterCurrent,
                    _waterUnit,
                  ),
                  summary:
                      meterSummary(_waterPrevious, _waterCurrent, _waterUnit),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _otherAmount,
                  label: 'Phí khác (đ)',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _nonNegativeInt,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _note,
                  label: 'Ghi chú',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SubmitButton(
                  label: 'Tạo hóa đơn',
                  loading: formState.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final leases = await ref.read(billingActiveLeasesProvider.future);
    if (!mounted) return;
    BillingLease? selectedLease;
    for (final lease in leases) {
      if (lease.id == _selectedLeaseId) {
        selectedLease = lease;
        break;
      }
    }
    if (!_formKey.currentState!.validate() || selectedLease == null) return;
    try {
      final electricity = meterDraft(
        UtilityType.electricity,
        _electricityPrevious,
        _electricityCurrent,
        _electricityUnit,
      );
      final water = meterDraft(
        UtilityType.water,
        _waterPrevious,
        _waterCurrent,
        _waterUnit,
      );
      await ref.read(billingFormControllerProvider.notifier).submit(
            lease: selectedLease,
            billingMonth: _month.text.trim(),
            meterReadings: [
              if (electricity != null) electricity,
              if (water != null) water,
            ],
            dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
            otherAmount: _parseInt(_otherAmount.text.trim()),
            note: _note.text,
          );
      if (mounted) context.pop();
    } catch (_) {
      // The provider state renders the error banner.
    }
  }

  void _handleMonthChanged() async {
    final List<BillingLease> leases;
    try {
      leases = await ref.read(billingActiveLeasesProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    for (final lease in leases) {
      if (lease.id == _selectedLeaseId) {
        _prefillForCurrentLease(lease);
        return;
      }
    }
  }

  void _prefillForCurrentLease([BillingLease? lease]) {
    final selected = lease;
    if (selected == null || _requiredDate(_month.text) != null) return;
    final billingMonth = DateTime.tryParse(_month.text.trim());
    if (billingMonth == null) return;
    final previousMonth = DateTime(billingMonth.year, billingMonth.month - 1);
    final month = _isoMonth(previousMonth);
    final key = '${selected.roomId}|$month';
    if (_lastPrefillKey == key) return;
    _lastPrefillKey = key;
    _electricityBaseline = null;
    _waterBaseline = null;
    final token = ++_prefillToken;

    ref
        .read(billingRepositoryProvider)
        .meterReadings(roomId: selected.roomId, month: month)
        .then((readings) {
      if (!mounted || token != _prefillToken) return;
      MeterReading? electricityBaseline;
      MeterReading? waterBaseline;
      for (final reading in readings) {
        if (reading.utilityType == UtilityType.electricity) {
          electricityBaseline = reading;
          _applyPreviousReading(
            reading,
            _electricityPrevious,
            _electricityCurrent,
            _electricityUnit,
          );
        } else {
          waterBaseline = reading;
          _applyPreviousReading(
            reading,
            _waterPrevious,
            _waterCurrent,
            _waterUnit,
          );
        }
      }
      setState(() {
        _electricityBaseline = electricityBaseline;
        _waterBaseline = waterBaseline;
      });
    });
  }

  void _applyPreviousReading(
    MeterReading reading,
    TextEditingController previous,
    TextEditingController current,
    TextEditingController unitPrice,
  ) {
    if (previous.text.trim().isEmpty &&
        current.text.trim().isEmpty &&
        unitPrice.text.trim().isEmpty) {
      previous.text = reading.currentReading.toString();
      unitPrice.text = reading.unitPrice.toString();
    }
  }

  static String _isoMonth(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month-01';
  }

  static String _defaultMonth() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month-01';
  }

  int _parseInt(String value) => int.parse(value.isEmpty ? '0' : value);

  String? _requiredDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nhập ngày hợp lệ.';
    return DateTime.tryParse(value.trim()) == null ? 'Nhập ngày hợp lệ.' : null;
  }

  String? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim()) == null ? 'Nhập ngày hợp lệ.' : null;
  }

  String? _nonNegativeInt(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return 'Nhập số hợp lệ.';
    return null;
  }

  String _friendlyError(Object? error) {
    if (error is BillingFormFailure) return error.message;
    if (error is ApiFailure) {
      return switch (error.code) {
        'INVOICE_EXISTS' => 'Hóa đơn tháng này đã tồn tại.',
        'METER_READING_EXISTS' =>
          'Chỉ số điện/nước của phòng này trong tháng đã tồn tại.',
        'INVALID_METER_READING' => 'Chỉ số mới không được nhỏ hơn chỉ số cũ.',
        'INVALID_UNIT_PRICE' => 'Đơn giá phải lớn hơn 0.',
        _ => error.message,
      };
    }
    return '$error';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _FixedFeeHint extends StatelessWidget {
  const _FixedFeeHint({required this.lease});

  final BillingLease lease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.add_card_rounded, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tự cộng phí cố định ${formatCurrencyVnd(lease.fixedFeeAmount)}'
              ' (${lease.fixedFees.map((fee) => fee.name).join(', ')})',
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration() => InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
      ),
    );

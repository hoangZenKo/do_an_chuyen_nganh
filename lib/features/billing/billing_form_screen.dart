import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/messaging/messaging_launcher.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../auth/auth_navigation.dart';
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
  int _step = 0;
  bool _electricityEnabled = true;
  bool _waterEnabled = true;
  bool _otherEnabled = true;
  String _delivery = 'app';
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
      _otherAmount,
    ]) {
      controller.addListener(_refreshDraft);
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
      _otherAmount,
    ]) {
      controller.removeListener(_refreshDraft);
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

  void _refreshDraft() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final leasesAsync =
        ref.watch(billingLeasesForMonthProvider(_selectedBillingMonth));
    final formState = ref.watch(billingFormControllerProvider);

    return Scaffold(
      backgroundColor: _InvoiceColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: _InvoiceColors.background,
        foregroundColor: _InvoiceColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Tạo hóa đơn',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: _InvoiceColors.accent,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('Hủy'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: leasesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _InvoiceColors.muted),
            ),
          ),
        ),
        data: (leases) {
          if (leases.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Chưa có hợp đồng đang thuê để tạo hóa đơn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _InvoiceColors.muted),
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

          final preview = _InvoiceDraft.from(
            lease: selectedLease,
            electricityEnabled: _electricityEnabled,
            waterEnabled: _waterEnabled,
            otherEnabled: _otherEnabled,
            electricityPrevious: _electricityPrevious,
            electricityCurrent: _electricityCurrent,
            electricityUnit: _electricityUnit,
            waterPrevious: _waterPrevious,
            waterCurrent: _waterCurrent,
            waterUnit: _waterUnit,
            otherAmount: _otherAmount,
          );

          return Form(
            key: _formKey,
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    _step == 1 ? 142 : 116,
                  ),
                  children: [
                    _StepHeader(step: _step),
                    const SizedBox(height: 22),
                    if (formState.hasError) ...[
                      FormErrorBanner(message: _friendlyError(formState.error)),
                      const SizedBox(height: 14),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: switch (_step) {
                        0 => _RoomStep(
                            key: const ValueKey('room-step'),
                            leases: leases,
                            selectedLease: selectedLease,
                            month: _month,
                            dueDate: _dueDate,
                            note: _note,
                            onLeaseChanged: (lease) {
                              setState(() {
                                _selectedLeaseId = lease.id;
                                _lastPrefillKey = null;
                              });
                              _prefillForCurrentLease(lease);
                            },
                            dateValidator: _requiredDate,
                            optionalDateValidator: _optionalDate,
                          ),
                        1 => _ChargesStep(
                            key: const ValueKey('charges-step'),
                            lease: selectedLease,
                            electricityEnabled: _electricityEnabled,
                            waterEnabled: _waterEnabled,
                            otherEnabled: _otherEnabled,
                            electricityPrevious: _electricityPrevious,
                            electricityCurrent: _electricityCurrent,
                            electricityUnit: _electricityUnit,
                            waterPrevious: _waterPrevious,
                            waterCurrent: _waterCurrent,
                            waterUnit: _waterUnit,
                            otherAmount: _otherAmount,
                            electricityBaseline: _electricityBaseline,
                            waterBaseline: _waterBaseline,
                            preview: preview,
                            onElectricityChanged: (value) => setState(
                              () => _electricityEnabled = value,
                            ),
                            onWaterChanged: (value) =>
                                setState(() => _waterEnabled = value),
                            onOtherChanged: (value) =>
                                setState(() => _otherEnabled = value),
                            meterValidator: _meterValidator,
                            amountValidator: _nonNegativeInt,
                          ),
                        _ => _PreviewStep(
                            key: const ValueKey('preview-step'),
                            lease: selectedLease,
                            preview: preview,
                            month: _month.text,
                            dueDate: _dueDate.text,
                            delivery: _delivery,
                            onDeliveryChanged: (value) =>
                                setState(() => _delivery = value),
                          ),
                      },
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _BottomActionBar(
                    step: _step,
                    loading: formState.isLoading,
                    preview: preview,
                    onBack: _step == 0 ? null : _goBack,
                    onNext: _continue,
                    onSubmit: _submit,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _goBack() {
    setState(() => _step = _step > 0 ? _step - 1 : 0);
  }

  void _cancel() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(billingRoute);
  }

  Future<void> _deliverCreatedInvoice(Invoice invoice) async {
    final message = _invoiceDeliveryMessage(invoice);
    if (_delivery == 'zalo') {
      await openMessagingApp(
        context,
        tenantId: invoice.tenantId,
        invoiceId: invoice.id,
        tenantName: invoice.tenantName,
        roomName: invoice.roomName,
        template: 'invoice_detail',
        message: message,
      );
      return;
    }
    if (_delivery == 'email') {
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject':
              'Hóa đơn phòng ${invoice.roomName ?? invoice.roomId} ${formatMonth(invoice.billingMonth)}',
          'body': message,
        },
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa mở được email. Đã copy nội dung hóa đơn.'),
            ),
          );
        }
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã tạo hóa đơn. Tenant có thể xem trong ứng dụng.'),
      ),
    );
  }

  void _continue() {
    if (_step == 0 && !_validateDates()) return;
    if (_step == 1 && !_validateCharges()) return;
    setState(() => _step = _step < 2 ? _step + 1 : 2);
  }

  bool _validateDates() {
    final monthError = _requiredDate(_month.text);
    final dueError = _optionalDate(_dueDate.text);
    if (monthError == null && dueError == null) return true;
    _showInputError(monthError ?? dueError ?? 'Kiểm tra lại ngày hóa đơn.');
    return false;
  }

  bool _validateCharges() {
    if (_formKey.currentState?.validate() ?? false) return true;
    _showInputError('Kiểm tra lại các chỉ số và đơn giá trước khi xem trước.');
    return false;
  }

  void _showInputError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final leases = await ref
        .read(billingLeasesForMonthProvider(_selectedBillingMonth).future);
    if (!mounted) return;
    BillingLease? selectedLease;
    for (final lease in leases) {
      if (lease.id == _selectedLeaseId) {
        selectedLease = lease;
        break;
      }
    }
    if (selectedLease == null) return;
    final datesValid = _validateDates();
    if (!datesValid) {
      setState(() => _step = 0);
      return;
    }
    if (!_validateCharges()) {
      setState(() => _step = 1);
      return;
    }
    try {
      final electricity = _electricityEnabled
          ? meterDraft(
              UtilityType.electricity,
              _electricityPrevious,
              _electricityCurrent,
              _electricityUnit,
            )
          : null;
      final water = _waterEnabled
          ? meterDraft(
              UtilityType.water,
              _waterPrevious,
              _waterCurrent,
              _waterUnit,
            )
          : null;
      final invoice = await ref
          .read(billingFormControllerProvider.notifier)
          .submit(
            lease: selectedLease,
            billingMonth: _month.text.trim(),
            meterReadings: [
              if (electricity != null) electricity,
              if (water != null) water,
            ],
            dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
            otherAmount:
                _otherEnabled ? _parseInt(_otherAmount.text.trim()) : 0,
            note: _note.text,
          );
      if (!mounted) return;
      await _deliverCreatedInvoice(invoice);
      if (mounted) context.pop();
    } catch (_) {
      // The provider state renders the error banner.
    }
  }

  String? Function(String?) _meterValidator(
    bool enabled,
    MeterReadingField field,
    TextEditingController previous,
    TextEditingController current,
    TextEditingController unitPrice,
  ) {
    if (!enabled) return (_) => null;
    return meterValidator(field, previous, current, unitPrice);
  }

  void _handleMonthChanged() async {
    setState(() {});
    final List<BillingLease> leases;
    try {
      leases = await ref
          .read(billingLeasesForMonthProvider(_selectedBillingMonth).future);
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

  String get _selectedBillingMonth {
    final date = DateTime.tryParse(_month.text.trim());
    if (date == null) return _defaultMonth();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-01';
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

class _InvoiceColors {
  const _InvoiceColors._();

  static const background = Color(0xFFF7F4EF);
  static const surface = Colors.white;
  static const ink = Color(0xFF152342);
  static const muted = Color(0xFF64708A);
  static const line = Color(0xFFE7E1D8);
  static const softLine = Color(0xFFF0E8DE);
  static const accent = Color(0xFFFF5A00);
  static const accentSoft = Color(0xFFFFEFE5);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF4EEFF);
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Chọn phòng', 'Khoản thu', 'Xem trước'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: step >= index
                              ? _InvoiceColors.accent
                              : _InvoiceColors.line,
                        ),
                      ),
                    _StepDot(index: index, currentStep: step),
                    if (index < labels.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: step > index
                              ? _InvoiceColors.accent
                              : _InvoiceColors.line,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: step == index
                        ? _InvoiceColors.ink
                        : _InvoiceColors.muted,
                    fontSize: 12,
                    fontWeight:
                        step == index ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final isDone = currentStep > index;
    final isActive = currentStep == index;
    final color =
        isDone || isActive ? _InvoiceColors.accent : const Color(0xFFD9DDE5);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isDone ? _InvoiceColors.accentSoft : color,
        border: Border.all(
          color: isDone || isActive ? _InvoiceColors.accent : color,
          width: 1.2,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isDone
            ? const Icon(
                Icons.check_rounded,
                size: 17,
                color: _InvoiceColors.accent,
              )
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : _InvoiceColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _RoomStep extends StatelessWidget {
  const _RoomStep({
    super.key,
    required this.leases,
    required this.selectedLease,
    required this.month,
    required this.dueDate,
    required this.note,
    required this.onLeaseChanged,
    required this.dateValidator,
    required this.optionalDateValidator,
  });

  final List<BillingLease> leases;
  final BillingLease selectedLease;
  final TextEditingController month;
  final TextEditingController dueDate;
  final TextEditingController note;
  final ValueChanged<BillingLease> onLeaseChanged;
  final String? Function(String?) dateValidator;
  final String? Function(String?) optionalDateValidator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Chọn phòng'),
        const SizedBox(height: 10),
        DropdownButtonFormField<BillingLease>(
          value: selectedLease,
          isExpanded: true,
          items: leases
              .map(
                (lease) => DropdownMenuItem(
                  value: lease,
                  child: Text(
                    'Phòng ${lease.roomName} - ${lease.tenantName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (lease) {
            if (lease != null) onLeaseChanged(lease);
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(
            color: _InvoiceColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          decoration: _inputDecoration(prefixIcon: Icons.apartment_rounded),
        ),
        const SizedBox(height: 14),
        _RoomHeroCard(lease: selectedLease),
        const SizedBox(height: 14),
        _TenantCard(lease: selectedLease),
        const SizedBox(height: 24),
        const _SectionTitle('Thông tin hóa đơn'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _LightTextField(
                controller: month,
                label: 'Tháng thanh toán',
                hint: '2026-08-01',
                icon: Icons.calendar_month_rounded,
                validator: dateValidator,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LightTextField(
                controller: dueDate,
                label: 'Hạn thanh toán',
                hint: '2026-08-10',
                icon: Icons.event_available_rounded,
                validator: optionalDateValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LightTextField(
          controller: note,
          label: 'Ghi chú (tùy chọn)',
          hint: 'Nhập ghi chú nếu có...',
          maxLines: 3,
        ),
      ],
    );
  }
}

class _RoomHeroCard extends StatelessWidget {
  const _RoomHeroCard({required this.lease});

  final BillingLease lease;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/rooms/room_01.jpeg',
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _InvoiceColors.accent.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Phòng đang thuê',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phòng ${lease.roomName}',
                  style: const TextStyle(
                    color: _InvoiceColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    const _RoomMeta(
                      icon: Icons.layers_rounded,
                      label: 'Đang thuê',
                    ),
                    _RoomMeta(
                      icon: Icons.payments_rounded,
                      label: formatCurrencyVnd(lease.monthlyRent),
                    ),
                    _RoomMeta(
                      icon: Icons.receipt_long_rounded,
                      label: lease.fixedFeeAmount > 0
                          ? '${lease.fixedFees.length} phí cố định'
                          : 'Không phí cố định',
                    ),
                    if (lease.startDate != null)
                      _RoomMeta(
                        icon: Icons.key_rounded,
                        label: 'Từ ${formatDate(lease.startDate)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomMeta extends StatelessWidget {
  const _RoomMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: _InvoiceColors.muted),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: _InvoiceColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.lease});

  final BillingLease lease;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: _InvoiceColors.blueSoft,
            child: Text(
              _initials(lease.tenantName),
              style: const TextStyle(
                color: _InvoiceColors.blue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Người thuê hiện tại',
                  style: TextStyle(
                    color: _InvoiceColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lease.tenantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _InvoiceColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hợp đồng ${lease.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _InvoiceColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _InvoiceColors.ink),
        ],
      ),
    );
  }
}

class _ChargesStep extends StatelessWidget {
  const _ChargesStep({
    super.key,
    required this.lease,
    required this.electricityEnabled,
    required this.waterEnabled,
    required this.otherEnabled,
    required this.electricityPrevious,
    required this.electricityCurrent,
    required this.electricityUnit,
    required this.waterPrevious,
    required this.waterCurrent,
    required this.waterUnit,
    required this.otherAmount,
    required this.electricityBaseline,
    required this.waterBaseline,
    required this.preview,
    required this.onElectricityChanged,
    required this.onWaterChanged,
    required this.onOtherChanged,
    required this.meterValidator,
    required this.amountValidator,
  });

  final BillingLease lease;
  final bool electricityEnabled;
  final bool waterEnabled;
  final bool otherEnabled;
  final TextEditingController electricityPrevious;
  final TextEditingController electricityCurrent;
  final TextEditingController electricityUnit;
  final TextEditingController waterPrevious;
  final TextEditingController waterCurrent;
  final TextEditingController waterUnit;
  final TextEditingController otherAmount;
  final MeterReading? electricityBaseline;
  final MeterReading? waterBaseline;
  final _InvoiceDraft preview;
  final ValueChanged<bool> onElectricityChanged;
  final ValueChanged<bool> onWaterChanged;
  final ValueChanged<bool> onOtherChanged;
  final String? Function(String?) Function(
    bool enabled,
    MeterReadingField field,
    TextEditingController previous,
    TextEditingController current,
    TextEditingController unitPrice,
  ) meterValidator;
  final String? Function(String?) amountValidator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Khoản thu'),
        const SizedBox(height: 10),
        _SimpleChargeCard(
          icon: Icons.home_rounded,
          iconColor: _InvoiceColors.accent,
          iconBackground: _InvoiceColors.accentSoft,
          title: 'Tiền phòng',
          subtitle: '${formatCurrencyVnd(lease.monthlyRent)} / tháng',
          amount: formatCurrencyVnd(preview.rent),
        ),
        const SizedBox(height: 10),
        _MeterChargeCard(
          icon: Icons.bolt_rounded,
          iconColor: _InvoiceColors.accent,
          iconBackground: _InvoiceColors.accentSoft,
          title: 'Tiền điện',
          subtitle: 'Nhập chỉ số và đơn giá theo kWh',
          unitLabel: 'kWh',
          enabled: electricityEnabled,
          onChanged: onElectricityChanged,
          previous: electricityPrevious,
          current: electricityCurrent,
          unitPrice: electricityUnit,
          amount: preview.electricity,
          baseline: electricityBaseline,
          validator: (
            field,
            previous,
            current,
            unitPrice,
          ) =>
              meterValidator(
            electricityEnabled,
            field,
            previous,
            current,
            unitPrice,
          ),
        ),
        const SizedBox(height: 10),
        _MeterChargeCard(
          icon: Icons.water_drop_rounded,
          iconColor: _InvoiceColors.blue,
          iconBackground: _InvoiceColors.blueSoft,
          title: 'Tiền nước',
          subtitle: 'Nhập chỉ số và đơn giá theo m³',
          unitLabel: 'm³',
          enabled: waterEnabled,
          onChanged: onWaterChanged,
          previous: waterPrevious,
          current: waterCurrent,
          unitPrice: waterUnit,
          amount: preview.water,
          baseline: waterBaseline,
          validator: (
            field,
            previous,
            current,
            unitPrice,
          ) =>
              meterValidator(
            waterEnabled,
            field,
            previous,
            current,
            unitPrice,
          ),
        ),
        const SizedBox(height: 10),
        _OtherChargeCard(
          lease: lease,
          enabled: otherEnabled,
          amountController: otherAmount,
          fixedAmount: lease.fixedFeeAmount,
          otherAmount: preview.other,
          validator: amountValidator,
          onChanged: onOtherChanged,
        ),
        const SizedBox(height: 10),
        const _AddOtherButton(),
      ],
    );
  }
}

class _SimpleChargeCard extends StatelessWidget {
  const _SimpleChargeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: [
          _IconTile(icon: icon, color: iconColor, background: iconBackground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _InvoiceColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _InvoiceColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              color: _InvoiceColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.lock_rounded,
            size: 18,
            color: _InvoiceColors.muted,
          ),
        ],
      ),
    );
  }
}

class _MeterChargeCard extends StatelessWidget {
  const _MeterChargeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.unitLabel,
    required this.enabled,
    required this.onChanged,
    required this.previous,
    required this.current,
    required this.unitPrice,
    required this.amount,
    required this.baseline,
    required this.validator,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String unitLabel;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final TextEditingController previous;
  final TextEditingController current;
  final TextEditingController unitPrice;
  final int amount;
  final MeterReading? baseline;
  final String? Function(String?) Function(
    MeterReadingField field,
    TextEditingController previous,
    TextEditingController current,
    TextEditingController unitPrice,
  ) validator;

  @override
  Widget build(BuildContext context) {
    final usage = _meterUsage(previous, current);
    return _SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              _IconTile(
                  icon: icon, color: iconColor, background: iconBackground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _InvoiceColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _InvoiceColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrencyVnd(amount),
                style: const TextStyle(
                  color: _InvoiceColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: enabled,
                activeColor: _InvoiceColors.accent,
                onChanged: onChanged,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                enabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _LightTextField(
                          controller: previous,
                          label: 'Chỉ số cũ',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: validator(
                            MeterReadingField.previous,
                            previous,
                            current,
                            unitPrice,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LightTextField(
                          controller: current,
                          label: 'Chỉ số mới',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: validator(
                            MeterReadingField.current,
                            previous,
                            current,
                            unitPrice,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child:
                            _ReadonlyUsage(value: usage, unitLabel: unitLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _LightTextField(
                          controller: unitPrice,
                          label: 'Đơn giá',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: validator(
                            MeterReadingField.unitPrice,
                            previous,
                            current,
                            unitPrice,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AmountBox(
                          label: 'Thành tiền',
                          value: formatCurrencyVnd(amount),
                        ),
                      ),
                    ],
                  ),
                  if (baseline != null) ...[
                    const SizedBox(height: 10),
                    _PreviousReadingInline(reading: baseline!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherChargeCard extends StatelessWidget {
  const _OtherChargeCard({
    required this.lease,
    required this.enabled,
    required this.amountController,
    required this.fixedAmount,
    required this.otherAmount,
    required this.validator,
    required this.onChanged,
  });

  final BillingLease lease;
  final bool enabled;
  final TextEditingController amountController;
  final int fixedAmount;
  final int otherAmount;
  final String? Function(String?) validator;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final feeNames = lease.fixedFees.map((fee) => fee.name).join(', ');
    final detailsVisible = fixedAmount > 0 || enabled;
    return _SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              const _IconTile(
                icon: Icons.fact_check_rounded,
                color: _InvoiceColors.purple,
                background: _InvoiceColors.purpleSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phí dịch vụ',
                      style: TextStyle(
                        color: _InvoiceColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fixedAmount > 0
                          ? '${formatCurrencyVnd(fixedAmount)} / tháng'
                          : 'Bật để thêm phụ thu',
                      style: const TextStyle(
                        color: _InvoiceColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrencyVnd(fixedAmount + (enabled ? otherAmount : 0)),
                style: const TextStyle(
                  color: _InvoiceColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              if (fixedAmount == 0)
                Switch.adaptive(
                  value: enabled,
                  activeColor: _InvoiceColors.accent,
                  onChanged: onChanged,
                )
              else
                const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: _InvoiceColors.muted,
                ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: detailsVisible
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (feeNames.isNotEmpty) ...[
                    Text(
                      'Phí cố định: $feeNames',
                      style: const TextStyle(
                        color: _InvoiceColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (fixedAmount == 0 || enabled)
                    _LightTextField(
                      controller: amountController,
                      label: 'Phụ thu khác',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: validator,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    super.key,
    required this.lease,
    required this.preview,
    required this.month,
    required this.dueDate,
    required this.delivery,
    required this.onDeliveryChanged,
  });

  final BillingLease lease;
  final _InvoiceDraft preview;
  final String month;
  final String dueDate;
  final String delivery;
  final ValueChanged<String> onDeliveryChanged;

  @override
  Widget build(BuildContext context) {
    final monthDate = DateTime.tryParse(month.trim());
    final dueDateValue = DateTime.tryParse(dueDate.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Xem trước hóa đơn'),
        const SizedBox(height: 10),
        _InvoicePreviewCard(
          lease: lease,
          preview: preview,
          month: monthDate,
          dueDate: dueDateValue,
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Gửi hóa đơn qua'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DeliveryOption(
                id: 'app',
                selectedId: delivery,
                icon: Icons.mark_unread_chat_alt_rounded,
                label: 'Trong ứng dụng',
                onSelected: onDeliveryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DeliveryOption(
                id: 'zalo',
                selectedId: delivery,
                icon: Icons.chat_bubble_rounded,
                label: 'Zalo',
                onSelected: onDeliveryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DeliveryOption(
                id: 'email',
                selectedId: delivery,
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                onSelected: onDeliveryChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InvoicePreviewCard extends StatelessWidget {
  const _InvoicePreviewCard({
    required this.lease,
    required this.preview,
    required this.month,
    required this.dueDate,
  });

  final BillingLease lease;
  final _InvoiceDraft preview;
  final DateTime? month;
  final DateTime? dueDate;

  @override
  Widget build(BuildContext context) {
    final fallback = DateTime.now();
    final invoiceYear = month?.year ?? fallback.year;
    final invoiceMonth =
        (month?.month ?? fallback.month).toString().padLeft(2, '0');
    return _SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        children: [
          const Text(
            'RENTAL ROOMS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _InvoiceColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'HÓA ĐƠN THANH TOÁN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _InvoiceColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Mã hóa đơn: HD-$invoiceYear$invoiceMonth-${lease.roomName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _InvoiceColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/rooms/room_01.jpeg',
                  width: 92,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phòng ${lease.roomName}',
                      style: const TextStyle(
                        color: _InvoiceColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hợp đồng ${lease.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _InvoiceColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MiniMeta(
                      icon: Icons.home_work_rounded,
                      label: formatCurrencyVnd(lease.monthlyRent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: _InvoiceColors.softLine),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 19,
                color: _InvoiceColors.muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Người thuê',
                      style: TextStyle(
                        color: _InvoiceColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      lease.tenantName,
                      style: const TextStyle(
                        color: _InvoiceColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: _InvoiceColors.softLine),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PreviewDate(
                  icon: Icons.access_time_rounded,
                  label: 'Kỳ thanh toán',
                  value: formatMonth(month),
                ),
              ),
              Container(width: 1, height: 38, color: _InvoiceColors.softLine),
              Expanded(
                child: _PreviewDate(
                  icon: Icons.event_available_rounded,
                  label: 'Hạn thanh toán',
                  value: dueDate == null ? 'Chưa đặt' : formatDate(dueDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: _InvoiceColors.softLine),
          const SizedBox(height: 10),
          _PreviewLine(label: 'Tiền phòng', amount: preview.rent),
          _PreviewLine(
            label:
                'Tiền điện (${preview.electricityUsage} kWh x ${formatCurrencyVnd(preview.electricityUnit)})',
            amount: preview.electricity,
            hidden: preview.electricity == 0,
          ),
          _PreviewLine(
            label:
                'Tiền nước (${preview.waterUsage} m³ x ${formatCurrencyVnd(preview.waterUnit)})',
            amount: preview.water,
            hidden: preview.water == 0,
          ),
          _PreviewLine(
            label: 'Phí dịch vụ',
            amount: preview.fixedFees + preview.other,
            hidden: preview.fixedFees + preview.other == 0,
          ),
          const SizedBox(height: 8),
          const Divider(color: _InvoiceColors.softLine),
          const SizedBox(height: 8),
          _PreviewLine(label: 'Tạm tính', amount: preview.total),
          const _PreviewLine(label: 'Giảm giá', amount: 0),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _InvoiceColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tổng thanh toán',
                    style: TextStyle(
                      color: _InvoiceColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  formatCurrencyVnd(preview.total),
                  style: const TextStyle(
                    color: _InvoiceColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.step,
    required this.loading,
    required this.preview,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final int step;
  final bool loading;
  final _InvoiceDraft preview;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isCharges = step == 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _InvoiceColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: isCharges
              ? Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _InvoiceColors.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng cộng (${preview.count} khoản)',
                            style: const TextStyle(
                              color: _InvoiceColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            formatCurrencyVnd(preview.total),
                            style: const TextStyle(
                              color: _InvoiceColors.accent,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _GhostButton(
                        onPressed: onBack, icon: Icons.chevron_left_rounded),
                    const SizedBox(width: 8),
                    _MiniPrimaryButton(
                      label: 'Chi tiết',
                      icon: Icons.expand_less_rounded,
                      onPressed: onNext,
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (onBack != null) ...[
                      _GhostButton(
                        onPressed: onBack,
                        icon: Icons.chevron_left_rounded,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: loading
                              ? null
                              : step == 2
                                  ? onSubmit
                                  : onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: _InvoiceColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Icon(
                                  step == 2
                                      ? Icons.send_rounded
                                      : Icons.arrow_forward_rounded,
                                ),
                          label: Text(
                            step == 2 ? 'Gửi hóa đơn' : 'Tiếp tục: Khoản thu',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LightTextField extends StatelessWidget {
  const _LightTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _InvoiceColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: const TextStyle(
            color: _InvoiceColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          decoration: _inputDecoration(hintText: hint, prefixIcon: icon),
        ),
      ],
    );
  }
}

class _ReadonlyUsage extends StatelessWidget {
  const _ReadonlyUsage({required this.value, required this.unitLabel});

  final int value;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sử dụng',
          style: TextStyle(
            color: _InvoiceColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F2F4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _InvoiceColors.line),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value $unitLabel',
              style: const TextStyle(
                color: _InvoiceColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _InvoiceColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _InvoiceColors.accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviousReadingInline extends StatelessWidget {
  const _PreviousReadingInline({required this.reading});

  final MeterReading reading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _InvoiceColors.line),
      ),
      child: Text(
        'Kỳ trước: ${reading.previousReading} -> ${reading.currentReading}, '
        'tiêu thụ ${reading.usage}, ${formatCurrencyVnd(reading.amount)}.',
        style: const TextStyle(
          color: _InvoiceColors.muted,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _InvoiceColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _InvoiceColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 26),
    );
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
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: _InvoiceColors.ink,
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _InvoiceColors.muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _InvoiceColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewDate extends StatelessWidget {
  const _PreviewDate({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _InvoiceColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _InvoiceColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _InvoiceColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.label,
    required this.amount,
    this.hidden = false,
  });

  final String label;
  final int amount;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _InvoiceColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount == 0 ? '- 0 đ' : formatCurrencyVnd(amount),
            style: TextStyle(
              color: amount == 0 ? _InvoiceColors.accent : _InvoiceColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.id,
    required this.selectedId,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final String id;
  final String selectedId;
  final IconData icon;
  final String label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = id == selectedId;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onSelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 76,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _InvoiceColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _InvoiceColors.accent : _InvoiceColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? _InvoiceColors.accent : _InvoiceColors.ink,
              size: 22,
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _InvoiceColors.ink : _InvoiceColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOtherButton extends StatelessWidget {
  const _AddOtherButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _InvoiceColors.accent.withValues(alpha: 0.36),
        ),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: _InvoiceColors.accent),
          SizedBox(width: 8),
          Text(
            'Thêm khoản thu khác',
            style: TextStyle(
              color: _InvoiceColors.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.onPressed, required this.icon});

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _InvoiceColors.ink,
          side: const BorderSide(color: _InvoiceColors.line),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _MiniPrimaryButton extends StatelessWidget {
  const _MiniPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _InvoiceColors.surface,
          foregroundColor: _InvoiceColors.ink,
          side: const BorderSide(color: _InvoiceColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _InvoiceDraft {
  const _InvoiceDraft({
    required this.rent,
    required this.fixedFees,
    required this.electricity,
    required this.electricityUsage,
    required this.electricityUnit,
    required this.water,
    required this.waterUsage,
    required this.waterUnit,
    required this.other,
  });

  final int rent;
  final int fixedFees;
  final int electricity;
  final int electricityUsage;
  final int electricityUnit;
  final int water;
  final int waterUsage;
  final int waterUnit;
  final int other;

  int get total => rent + fixedFees + electricity + water + other;

  int get count {
    var result = 0;
    if (rent > 0) result++;
    if (electricity > 0) result++;
    if (water > 0) result++;
    if (fixedFees + other > 0) result++;
    return result;
  }

  static _InvoiceDraft from({
    required BillingLease lease,
    required bool electricityEnabled,
    required bool waterEnabled,
    required bool otherEnabled,
    required TextEditingController electricityPrevious,
    required TextEditingController electricityCurrent,
    required TextEditingController electricityUnit,
    required TextEditingController waterPrevious,
    required TextEditingController waterCurrent,
    required TextEditingController waterUnit,
    required TextEditingController otherAmount,
  }) {
    final electricityData = _meterAmount(
      enabled: electricityEnabled,
      previous: electricityPrevious,
      current: electricityCurrent,
      unitPrice: electricityUnit,
    );
    final waterData = _meterAmount(
      enabled: waterEnabled,
      previous: waterPrevious,
      current: waterCurrent,
      unitPrice: waterUnit,
    );
    return _InvoiceDraft(
      rent: lease.monthlyRent,
      fixedFees: lease.fixedFeeAmount,
      electricity: electricityData.amount,
      electricityUsage: electricityData.usage,
      electricityUnit: electricityData.unitPrice,
      water: waterData.amount,
      waterUsage: waterData.usage,
      waterUnit: waterData.unitPrice,
      other: otherEnabled ? (int.tryParse(otherAmount.text.trim()) ?? 0) : 0,
    );
  }
}

class _MeterAmount {
  const _MeterAmount({
    required this.amount,
    required this.usage,
    required this.unitPrice,
  });

  final int amount;
  final int usage;
  final int unitPrice;
}

_MeterAmount _meterAmount({
  required bool enabled,
  required TextEditingController previous,
  required TextEditingController current,
  required TextEditingController unitPrice,
}) {
  if (!enabled) {
    return const _MeterAmount(amount: 0, usage: 0, unitPrice: 0);
  }
  final oldValue = int.tryParse(previous.text.trim());
  final newValue = int.tryParse(current.text.trim());
  final unitValue = int.tryParse(unitPrice.text.trim());
  if (oldValue == null ||
      newValue == null ||
      unitValue == null ||
      newValue < oldValue ||
      unitValue <= 0) {
    return _MeterAmount(amount: 0, usage: 0, unitPrice: unitValue ?? 0);
  }
  final usage = newValue - oldValue;
  return _MeterAmount(
    amount: usage * unitValue,
    usage: usage,
    unitPrice: unitValue,
  );
}

int _meterUsage(
  TextEditingController previous,
  TextEditingController current,
) {
  final oldValue = int.tryParse(previous.text.trim());
  final newValue = int.tryParse(current.text.trim());
  if (oldValue == null || newValue == null || newValue < oldValue) return 0;
  return newValue - oldValue;
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'K';
  final chars = words.take(2).map((word) => word.characters.first).join();
  return chars.toUpperCase();
}

String _invoiceDeliveryMessage(Invoice invoice) {
  return [
    'HÓA ĐƠN PHÒNG ${invoice.roomName ?? invoice.roomId}',
    'Khách thuê: ${invoice.tenantName ?? 'Khách thuê'}',
    'Tháng: ${formatMonth(invoice.billingMonth)}',
    'Hạn thanh toán: ${formatDate(invoice.dueDate)}',
    '',
    'Tiền phòng: ${formatCurrencyVnd(invoice.rentAmount)}',
    'Điện: ${formatCurrencyVnd(invoice.electricityAmount)}',
    'Nước: ${formatCurrencyVnd(invoice.waterAmount)}',
    if (invoice.otherAmount > 0)
      'Phí khác: ${formatCurrencyVnd(invoice.otherAmount)}',
    'Tổng thanh toán: ${formatCurrencyVnd(invoice.totalAmount)}',
  ].join('\n');
}

InputDecoration _inputDecoration({
  String? hintText,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF9BA3B4),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 18, color: _InvoiceColors.blue),
    filled: true,
    fillColor: _InvoiceColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _InvoiceColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _InvoiceColors.accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.red, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.red, width: 1.5),
    ),
  );
}

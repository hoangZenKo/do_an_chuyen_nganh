import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/property.dart';
import '../auth/auth_navigation.dart';
import '../reports/reports_providers.dart';
import '../rooms/room_providers.dart';
import '../tenants/widgets/form_widgets.dart';
import 'billing_providers.dart';
import 'widgets/meter_reading_fields.dart';

class BulkInvoiceScreen extends ConsumerStatefulWidget {
  const BulkInvoiceScreen({super.key});

  @override
  ConsumerState<BulkInvoiceScreen> createState() => _BulkInvoiceScreenState();
}

class _BulkInvoiceScreenState extends ConsumerState<BulkInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _month = TextEditingController(text: _defaultMonth());
  final _dueDate = TextEditingController();
  final Map<String, _LeaseReadingControllers> _controllers = {};
  final Set<String> _prefilledReadingKeys = {};

  @override
  void initState() {
    super.initState();
    _month.addListener(_refreshPreflight);
  }

  @override
  void dispose() {
    _month.removeListener(_refreshPreflight);
    _month.dispose();
    _dueDate.dispose();
    for (final controllers in _controllers.values) {
      controllers.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final selectedPropertyId = ref.watch(selectedPropertyProvider);
    final formState = ref.watch(bulkInvoiceControllerProvider);
    final automationState = ref.watch(billingAutomationControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Tạo hóa đơn hàng loạt',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: propertiesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => _CenteredMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được khu trọ',
          message: '$error',
          action: TextButton(
            onPressed: () => ref.invalidate(propertiesProvider),
            child: const Text('Thử lại'),
          ),
        ),
        data: (properties) {
          final selectedProperty = _selectedProperty(
            properties,
            selectedPropertyId,
          );
          if (selectedProperty == null) {
            return _CenteredMessage(
              icon: Icons.apartment_rounded,
              title: 'Chưa chọn khu trọ',
              message: 'Vui lòng chọn khu trọ trước khi tạo hóa đơn tháng.',
              action: ElevatedButton.icon(
                onPressed: () => context.push(propertiesRoute),
                icon: const Icon(Icons.home_work_rounded),
                label: const Text('Chọn khu trọ'),
              ),
            );
          }

          final monthError = _requiredDate(_month.text);
          final key = monthError == null
              ? BulkInvoicePreflightKey(
                  propertyId: selectedProperty.id,
                  billingMonth: _month.text.trim(),
                )
              : null;
          final preflightAsync = key == null
              ? const AsyncValue<BulkInvoicePreflight>.data(
                  BulkInvoicePreflight(
                    propertyId: '',
                    billingMonth: null,
                    totalCount: 0,
                    readyCount: 0,
                    existingCount: 0,
                    items: [],
                  ),
                )
              : ref.watch(bulkInvoicePreflightProvider(key));
          final automationAsync =
              ref.watch(billingAutomationProvider(selectedProperty.id));
          final automationPreviewAsync = key == null
              ? const AsyncValue<BillingAutomationPreview>.data(
                  BillingAutomationPreview(
                    automation: BillingAutomation(
                      id: '',
                      landlordId: '',
                      propertyId: '',
                      isEnabled: false,
                      invoiceDay: 1,
                      dueDay: 10,
                    ),
                    preflight: BulkInvoicePreflight(
                      propertyId: '',
                      billingMonth: null,
                      totalCount: 0,
                      readyCount: 0,
                      existingCount: 0,
                      items: [],
                    ),
                  ),
                )
              : ref.watch(billingAutomationPreviewProvider(
                  BillingAutomationPreviewKey(
                    propertyId: selectedProperty.id,
                    billingMonth: _month.text.trim(),
                  ),
                ));

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PropertyBanner(
                  name: selectedProperty.name,
                  address: selectedProperty.address,
                ),
                const SizedBox(height: 12),
                const _BulkInvoiceExplainer(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _month,
                        label: 'Kỳ thanh toán',
                        labelColor: const Color(0xFF334155),
                        hint: '2026-08-01',
                        validator: _requiredDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _dueDate,
                        label: 'Hạn thanh toán',
                        labelColor: const Color(0xFF334155),
                        hint: '2026-08-10',
                        validator: _optionalDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: key == null
                        ? () => setState(() {})
                        : () {
                            ref.invalidate(bulkInvoicePreflightProvider(key));
                            setState(() {});
                          },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tải lại kỳ này'),
                  ),
                ),
                _AutomationCard(
                  propertyId: selectedProperty.id,
                  billingMonth: _month.text.trim(),
                  automationAsync: automationAsync,
                  previewAsync: automationPreviewAsync,
                  loading: automationState.isLoading,
                  onRun: (preflight) => _runAutomation(
                    selectedProperty.id,
                    preflight,
                  ),
                ),
                if (formState.hasError) ...[
                  const SizedBox(height: 8),
                  FormErrorBanner(message: _friendlyError(formState.error)),
                ],
                if (automationState.hasError) ...[
                  const SizedBox(height: 8),
                  FormErrorBanner(
                      message: _friendlyError(automationState.error)),
                ],
                if (formState.hasValue && formState.value != null) ...[
                  const SizedBox(height: 12),
                  _ResultCard(
                    propertyId: selectedProperty.id,
                    result: formState.value!,
                  ),
                ],
                if (automationState.hasValue &&
                    automationState.value != null) ...[
                  const SizedBox(height: 12),
                  _ResultCard(
                    propertyId: selectedProperty.id,
                    result: automationState.value!.result,
                  ),
                ],
                const SizedBox(height: 12),
                preflightAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),
                  error: (error, _) => FormErrorBanner(message: '$error'),
                  data: (preflight) {
                    if (key == null) {
                      return const FormErrorBanner(
                        message:
                            'Nhập tháng hóa đơn hợp lệ để tải danh sách phòng.',
                      );
                    }
                    _syncControllers(preflight.items);
                    if (preflight.items.isEmpty) {
                      return const _CenteredMessage(
                        icon: Icons.receipt_long_outlined,
                        title: 'Không có hợp đồng đang thuê',
                        message:
                            'Khu trọ này chưa có phòng nào đang có hợp đồng hoạt động.',
                      );
                    }

                    final missingCount = _missingReadingCount(preflight.items);
                    final previews = _invoicePreviews(preflight);
                    final readyTotal = previews.values
                        .where((preview) => preview.canCreate)
                        .fold<int>(0, (sum, preview) => sum + preview.total);
                    final warningCount = previews.values.fold<int>(
                      0,
                      (sum, preview) => sum + preview.warningCount,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FinalizationBoard(
                          readyCount: preflight.readyCount,
                          existingCount: preflight.existingCount,
                          missingCount: missingCount,
                          warningCount: warningCount,
                          readyTotal: readyTotal,
                        ),
                        const SizedBox(height: 12),
                        _BulkSummary(
                          readyCount: preflight.readyCount,
                          existingCount: preflight.existingCount,
                          missingCount: missingCount,
                          readyTotal: readyTotal,
                        ),
                        const SizedBox(height: 12),
                        for (final item in preflight.items) ...[
                          _LeaseInvoiceCard(
                            item: item,
                            controllers: _controllers[item.leaseId]!,
                            preview: previews[item.leaseId]!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SubmitBulkButton(
                          label: preflight.readyCount == 0
                              ? 'Tất cả đã có hóa đơn'
                              : missingCount > 0
                                  ? 'Nhập đủ chỉ số để tạo hóa đơn'
                                  : 'Tạo ${preflight.readyCount} hóa đơn',
                          loading: formState.isLoading,
                          enabled:
                              preflight.readyCount > 0 && missingCount == 0,
                          onPressed: () =>
                              _submit(selectedProperty.id, preflight),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _refreshPreflight() {
    _prefilledReadingKeys.clear();
    for (final controllers in _controllers.values) {
      controllers.clearBaselines();
    }
    if (mounted) setState(() {});
  }

  Property? _selectedProperty(
    List<Property> properties,
    String? selectedPropertyId,
  ) {
    for (final property in properties) {
      if (property.id == selectedPropertyId) return property;
    }
    return properties.isEmpty ? null : properties.first;
  }

  void _syncControllers(List<BulkInvoicePreflightItem> items) {
    final ids = items.map((item) => item.leaseId).toSet();
    final stale = _controllers.keys.where((id) => !ids.contains(id)).toList();
    for (final id in stale) {
      _controllers.remove(id)?.dispose();
    }
    for (final item in items) {
      _controllers.putIfAbsent(
        item.leaseId,
        () => _LeaseReadingControllers(onChanged: () {
          if (mounted) setState(() {});
        }),
      );
      _prefillPreviousReadings(item);
    }
  }

  int _missingReadingCount(List<BulkInvoicePreflightItem> items) {
    var count = 0;
    for (final item in items.where((item) => !item.hasInvoice)) {
      final controllers = _controllers[item.leaseId];
      if (controllers == null) continue;
      if (item.meterReadings.electricity == null &&
          meterBlank(
            controllers.electricityPrevious,
            controllers.electricityCurrent,
            controllers.electricityUnit,
          )) {
        count++;
      }
      if (item.meterReadings.water == null &&
          meterBlank(
            controllers.waterPrevious,
            controllers.waterCurrent,
            controllers.waterUnit,
          )) {
        count++;
      }
    }
    return count;
  }

  Map<String, _InvoiceDraftPreview> _invoicePreviews(
    BulkInvoicePreflight preflight,
  ) {
    return {
      for (final item in preflight.items)
        item.leaseId: _invoicePreviewFor(
          item,
          _controllers[item.leaseId],
        ),
    };
  }

  _InvoiceDraftPreview _invoicePreviewFor(
    BulkInvoicePreflightItem item,
    _LeaseReadingControllers? controllers,
  ) {
    if (item.invoice != null) {
      return _InvoiceDraftPreview.existing(item.invoice!.totalAmount);
    }
    if (controllers == null) {
      return _InvoiceDraftPreview.pending(
        rent: item.monthlyRent,
        fixedFees: item.fixedFeeAmount,
      );
    }
    final electricity = _meterPreview(
      existing: item.meterReadings.electricity,
      previous: controllers.electricityPrevious,
      current: controllers.electricityCurrent,
      unitPrice: controllers.electricityUnit,
      baseline: controllers.electricityBaseline,
    );
    final water = _meterPreview(
      existing: item.meterReadings.water,
      previous: controllers.waterPrevious,
      current: controllers.waterCurrent,
      unitPrice: controllers.waterUnit,
      baseline: controllers.waterBaseline,
    );
    return _InvoiceDraftPreview(
      rent: item.monthlyRent,
      fixedFees: item.fixedFeeAmount,
      electricity: electricity.amount,
      water: water.amount,
      missingCount: electricity.missingCount + water.missingCount,
      invalidCount: electricity.invalidCount + water.invalidCount,
      warningCount: electricity.warningCount + water.warningCount,
      existing: false,
    );
  }

  _MeterDraftPreview _meterPreview({
    required MeterReading? existing,
    required TextEditingController previous,
    required TextEditingController current,
    required TextEditingController unitPrice,
    required MeterReading? baseline,
  }) {
    if (existing != null) {
      return _MeterDraftPreview(amount: existing.amount);
    }
    if (meterBlank(previous, current, unitPrice)) {
      return const _MeterDraftPreview(missingCount: 1);
    }
    final oldValue = int.tryParse(previous.text.trim());
    final newValue = int.tryParse(current.text.trim());
    final unitValue = int.tryParse(unitPrice.text.trim());
    if (oldValue == null ||
        newValue == null ||
        unitValue == null ||
        newValue < oldValue ||
        unitValue <= 0) {
      return const _MeterDraftPreview(invalidCount: 1);
    }
    final insight = meterInsight(previous, current, unitPrice, baseline);
    final hasWarning = insight?.level == MeterInsightLevel.warning ||
        insight?.level == MeterInsightLevel.danger;
    return _MeterDraftPreview(
      amount: (newValue - oldValue) * unitValue,
      warningCount: hasWarning ? 1 : 0,
    );
  }

  void _prefillPreviousReadings(BulkInvoicePreflightItem item) {
    if (item.hasInvoice || _requiredDate(_month.text) != null) return;
    final billingMonth = DateTime.tryParse(_month.text.trim());
    if (billingMonth == null) return;
    final previousMonth = DateTime(billingMonth.year, billingMonth.month - 1);
    final month = _isoMonth(previousMonth);
    final key = '${item.roomId}|$month';
    if (!_prefilledReadingKeys.add(key)) return;
    final controllers = _controllers[item.leaseId];
    if (controllers == null) return;

    final suggested = item.suggestedMeterReadings;
    if (suggested.electricity != null || suggested.water != null) {
      if (suggested.electricity != null) {
        controllers.electricityBaseline = suggested.electricity;
        _applyPreviousReading(
          suggested.electricity!,
          controllers.electricityPrevious,
          controllers.electricityCurrent,
          controllers.electricityUnit,
        );
      }
      if (suggested.water != null) {
        controllers.waterBaseline = suggested.water;
        _applyPreviousReading(
          suggested.water!,
          controllers.waterPrevious,
          controllers.waterCurrent,
          controllers.waterUnit,
        );
      }
      return;
    }

    ref
        .read(billingRepositoryProvider)
        .meterReadings(roomId: item.roomId, month: month)
        .then((readings) {
      if (!mounted) return;
      final controllers = _controllers[item.leaseId];
      if (controllers == null) return;
      for (final reading in readings) {
        if (reading.utilityType == UtilityType.electricity) {
          controllers.electricityBaseline = reading;
          _applyPreviousReading(
            reading,
            controllers.electricityPrevious,
            controllers.electricityCurrent,
            controllers.electricityUnit,
          );
        } else {
          controllers.waterBaseline = reading;
          _applyPreviousReading(
            reading,
            controllers.waterPrevious,
            controllers.waterCurrent,
            controllers.waterUnit,
          );
        }
      }
      setState(() {});
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

  Future<void> _submit(
      String propertyId, BulkInvoicePreflight preflight) async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận tạo hóa đơn'),
        content: Text(
          'Tạo ${preflight.readyCount} hóa đơn cho tháng ${_month.text.trim()}? '
          'Các phòng đã có hóa đơn sẽ được bỏ qua.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo hóa đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final readings = _readingDrafts(preflight);
    try {
      await ref.read(bulkInvoiceControllerProvider.notifier).submit(
            propertyId: propertyId,
            billingMonth: _month.text.trim(),
            dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
            readings: readings,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo hóa đơn tháng.')),
        );
      }
    } catch (_) {
      // Provider state renders the error banner.
    }
  }

  List<BulkInvoiceReadingDraft> _readingDrafts(BulkInvoicePreflight preflight) {
    final readings = <BulkInvoiceReadingDraft>[];
    for (final item in preflight.items.where((item) => !item.hasInvoice)) {
      final controllers = _controllers[item.leaseId]!;
      final electricity = item.meterReadings.electricity == null
          ? meterDraft(
              UtilityType.electricity,
              controllers.electricityPrevious,
              controllers.electricityCurrent,
              controllers.electricityUnit,
            )
          : null;
      final water = item.meterReadings.water == null
          ? meterDraft(
              UtilityType.water,
              controllers.waterPrevious,
              controllers.waterCurrent,
              controllers.waterUnit,
            )
          : null;
      final drafts = <BillingMeterReadingDraft>[
        if (electricity != null) electricity,
        if (water != null) water,
      ];
      if (drafts.isNotEmpty) {
        readings.add(BulkInvoiceReadingDraft(
          leaseId: item.leaseId,
          meterReadings: drafts,
        ));
      }
    }
    return readings;
  }

  Future<void> _runAutomation(
    String propertyId,
    BulkInvoicePreflight preflight,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final missingCount = _missingReadingCount(preflight.items);
    if (missingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập đủ chỉ số trước khi chạy tự động.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chạy tự động lập hóa đơn'),
        content: Text(
          'Tạo ${preflight.readyCount} hóa đơn cho tháng ${_month.text.trim()} '
          'theo cấu hình tự động?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chạy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(billingAutomationControllerProvider.notifier).run(
            propertyId: propertyId,
            billingMonth: _month.text.trim(),
            readings: _readingDrafts(preflight),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chạy tự động lập hóa đơn.')),
        );
      }
    } catch (_) {
      // Provider state renders the error banner.
    }
  }

  static String _defaultMonth() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month-01';
  }

  static String _isoMonth(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month-01';
  }

  String? _requiredDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nhập ngày hợp lệ.';
    return DateTime.tryParse(value.trim()) == null ? 'Nhập ngày hợp lệ.' : null;
  }

  String? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim()) == null ? 'Nhập ngày hợp lệ.' : null;
  }

  String _friendlyError(Object? error) {
    if (error is ApiFailure) {
      return switch (error.code) {
        'PROPERTY_NOT_FOUND' =>
          'Không tìm thấy khu trọ hoặc khu trọ đã lưu trữ.',
        'INVOICE_EXISTS' => 'Một số hóa đơn tháng này đã tồn tại.',
        'METER_READING_EXISTS' =>
          'Một số chỉ số điện/nước tháng này đã tồn tại.',
        'INVALID_METER_READING' => 'Chỉ số mới không được nhỏ hơn chỉ số cũ.',
        'INVALID_UNIT_PRICE' => 'Đơn giá phải lớn hơn 0.',
        _ => error.message,
      };
    }
    return '$error';
  }
}

class _LeaseReadingControllers {
  _LeaseReadingControllers({required VoidCallback onChanged}) {
    for (final controller in _all) {
      controller.addListener(onChanged);
    }
    _onChanged = onChanged;
  }

  late final VoidCallback _onChanged;
  final electricityPrevious = TextEditingController();
  final electricityCurrent = TextEditingController();
  final electricityUnit = TextEditingController();
  final waterPrevious = TextEditingController();
  final waterCurrent = TextEditingController();
  final waterUnit = TextEditingController();
  MeterReading? electricityBaseline;
  MeterReading? waterBaseline;

  List<TextEditingController> get _all => [
        electricityPrevious,
        electricityCurrent,
        electricityUnit,
        waterPrevious,
        waterCurrent,
        waterUnit,
      ];

  void dispose() {
    for (final controller in _all) {
      controller.removeListener(_onChanged);
      controller.dispose();
    }
  }

  void clearBaselines() {
    electricityBaseline = null;
    waterBaseline = null;
  }
}

class _MeterDraftPreview {
  const _MeterDraftPreview({
    this.amount = 0,
    this.missingCount = 0,
    this.invalidCount = 0,
    this.warningCount = 0,
  });

  final int amount;
  final int missingCount;
  final int invalidCount;
  final int warningCount;
}

class _InvoiceDraftPreview {
  const _InvoiceDraftPreview({
    required this.rent,
    required this.fixedFees,
    required this.electricity,
    required this.water,
    required this.missingCount,
    required this.invalidCount,
    required this.warningCount,
    required this.existing,
  });

  const _InvoiceDraftPreview.pending({
    required int rent,
    required int fixedFees,
  }) : this(
          rent: rent,
          fixedFees: fixedFees,
          electricity: 0,
          water: 0,
          missingCount: 2,
          invalidCount: 0,
          warningCount: 0,
          existing: false,
        );

  const _InvoiceDraftPreview.existing(int total)
      : this(
          rent: total,
          fixedFees: 0,
          electricity: 0,
          water: 0,
          missingCount: 0,
          invalidCount: 0,
          warningCount: 0,
          existing: true,
        );

  final int rent;
  final int fixedFees;
  final int electricity;
  final int water;
  final int missingCount;
  final int invalidCount;
  final int warningCount;
  final bool existing;

  int get total => rent + fixedFees + electricity + water;

  bool get canCreate => !existing && missingCount == 0 && invalidCount == 0;
}

class _AutomationCard extends ConsumerStatefulWidget {
  const _AutomationCard({
    required this.propertyId,
    required this.billingMonth,
    required this.automationAsync,
    required this.previewAsync,
    required this.loading,
    required this.onRun,
  });

  final String propertyId;
  final String billingMonth;
  final AsyncValue<BillingAutomation> automationAsync;
  final AsyncValue<BillingAutomationPreview> previewAsync;
  final bool loading;
  final ValueChanged<BulkInvoicePreflight> onRun;

  @override
  ConsumerState<_AutomationCard> createState() => _AutomationCardState();
}

class _AutomationCardState extends ConsumerState<_AutomationCard> {
  var _enabled = false;
  var _invoiceDay = 1;
  var _dueDay = 10;
  String? _loadedPropertyId;

  @override
  Widget build(BuildContext context) {
    return widget.automationAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 4),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (error, _) => FormErrorBanner(message: '$error'),
      data: (automation) {
        _sync(automation);
        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tự động lập hóa đơn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: widget.loading
                        ? null
                        : (value) => setState(() => _enabled = value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DayPicker(
                      label: 'Ngày lập',
                      value: _invoiceDay,
                      onChanged: widget.loading
                          ? null
                          : (value) => setState(() => _invoiceDay = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DayPicker(
                      label: 'Hạn trả',
                      value: _dueDay,
                      onChanged: widget.loading
                          ? null
                          : (value) => setState(() => _dueDay = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              widget.previewAsync.when(
                loading: () => const Text(
                  'Đang tính preview...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                error: (_, __) => const Text(
                  'Chưa có preview cho tháng này.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                ),
                data: (preview) => _AutomationPreviewLine(
                  preview: preview,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: widget.loading ? null : () => _save(context),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Lưu cấu hình'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.loading || !_enabled
                          ? null
                          : () => widget.previewAsync.whenOrNull(
                                data: (preview) =>
                                    widget.onRun(preview.preflight),
                              ),
                      icon: widget.loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: const Text('Chạy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sync(BillingAutomation automation) {
    if (_loadedPropertyId == automation.propertyId) return;
    _loadedPropertyId = automation.propertyId;
    _enabled = automation.isEnabled;
    _invoiceDay = automation.invoiceDay == 0 ? 1 : automation.invoiceDay;
    _dueDay = automation.dueDay == 0 ? 10 : automation.dueDay;
  }

  Future<void> _save(BuildContext context) async {
    try {
      final saved =
          await ref.read(billingAutomationControllerProvider.notifier).save(
                propertyId: widget.propertyId,
                isEnabled: _enabled,
                invoiceDay: _invoiceDay,
                dueDay: _dueDay,
              );
      _loadedPropertyId = null;
      _sync(saved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cấu hình tự động.')),
        );
      }
    } catch (_) {
      // Provider state renders the error banner.
    }
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value.clamp(1, 28),
          isExpanded: true,
          dropdownColor: Colors.white,
          iconEnabledColor: const Color(0xFF334155),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          items: [
            for (var day = 1; day <= 28; day++)
              DropdownMenuItem(value: day, child: Text('Ngày $day')),
          ],
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value != null) onChanged!(value);
                },
        ),
      ),
    );
  }
}

class _AutomationPreviewLine extends StatelessWidget {
  const _AutomationPreviewLine({required this.preview});

  final BillingAutomationPreview preview;

  @override
  Widget build(BuildContext context) {
    final missing = _previewMissingReadings(preview.preflight.items);
    final dueDate =
        preview.dueDate == null ? 'chưa đặt' : formatDate(preview.dueDate);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MiniBadge(
          icon: Icons.receipt_long_rounded,
          text: '${preview.preflight.readyCount} sẽ tạo',
        ),
        _MiniBadge(
          icon: Icons.history_rounded,
          text: '${preview.preflight.existingCount} đã có',
        ),
        _MiniBadge(
          icon: Icons.speed_rounded,
          text: '$missing thiếu chỉ số',
          warning: missing > 0,
        ),
        _MiniBadge(
          icon: Icons.event_available_rounded,
          text: 'Hạn $dueDate',
        ),
      ],
    );
  }

  static int _previewMissingReadings(List<BulkInvoicePreflightItem> items) {
    var count = 0;
    for (final item in items.where((item) => !item.hasInvoice)) {
      if (item.meterReadings.electricity == null) count++;
      if (item.meterReadings.water == null) count++;
    }
    return count;
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFD97706) : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBulkButton extends StatelessWidget {
  const _SubmitBulkButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading || !enabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _PropertyBanner extends StatelessWidget {
  const _PropertyBanner({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkInvoiceExplainer extends StatelessWidget {
  const _BulkInvoiceExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, color: Color(0xFF1D4ED8)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Màn này tạo hóa đơn cho nhiều phòng trong cùng một kỳ. '
              'Phòng đã có hóa đơn sẽ được bỏ qua; phòng thiếu chỉ số điện/nước cần nhập đủ trước khi tạo.',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalizationBoard extends StatelessWidget {
  const _FinalizationBoard({
    required this.readyCount,
    required this.existingCount,
    required this.missingCount,
    required this.warningCount,
    required this.readyTotal,
  });

  final int readyCount;
  final int existingCount;
  final int missingCount;
  final int warningCount;
  final int readyTotal;

  @override
  Widget build(BuildContext context) {
    final canCreate = readyCount > 0 && missingCount == 0;
    final title = canCreate
        ? 'Đã sẵn sàng chốt hóa đơn tháng'
        : 'Hoàn tất chỉ số trước khi chốt tháng';
    final message = canCreate
        ? 'Có $readyCount phòng sẵn sàng tạo với tổng dự kiến ${formatCurrencyVnd(readyTotal)}.'
        : 'Còn $missingCount mục điện/nước cần nhập để tránh lập thiếu tiền.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canCreate ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canCreate ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: canCreate
                      ? const Color(0xFF059669)
                      : AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  canCreate ? Icons.fact_check_rounded : Icons.speed_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _FlowStep(
            done: true,
            text: 'Chọn khu trọ và tháng hóa đơn',
          ),
          _FlowStep(
            done: missingCount == 0,
            warning: missingCount > 0,
            text: missingCount == 0
                ? 'Đã đủ chỉ số điện/nước'
                : 'Còn $missingCount chỉ số cần nhập',
          ),
          _FlowStep(
            done: canCreate,
            warning: warningCount > 0,
            text: warningCount == 0
                ? 'Preview tiền phòng đã sẵn sàng'
                : '$warningCount chỉ số tăng bất thường cần xem lại',
          ),
          _FlowStep(
            done: false,
            text: existingCount == 0
                ? 'Bấm tạo hóa đơn rồi gửi nhắc tenant'
                : 'Bấm tạo hóa đơn, bỏ qua $existingCount phòng đã có',
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.done,
    required this.text,
    this.warning = false,
  });

  final bool done;
  final bool warning;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? const Color(0xFFD97706)
        : done
            ? AppTheme.primary
            : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : warning
                    ? Icons.warning_amber_rounded
                    : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkSummary extends StatelessWidget {
  const _BulkSummary({
    required this.readyCount,
    required this.existingCount,
    required this.missingCount,
    required this.readyTotal,
  });

  final int readyCount;
  final int existingCount;
  final int missingCount;
  final int readyTotal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _SummaryTile(label: 'Sẽ tạo', value: '$readyCount')),
            const SizedBox(width: 8),
            Expanded(
                child: _SummaryTile(label: 'Đã có', value: '$existingCount')),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(label: 'Thiếu', value: '$missingCount'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SummaryTile(
          label: 'Tổng dự kiến sẵn sàng tạo',
          value: formatCurrencyVnd(readyTotal),
          wide: true,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: wide ? 12 : 11,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: wide ? 17 : 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaseInvoiceCard extends StatelessWidget {
  const _LeaseInvoiceCard({
    required this.item,
    required this.controllers,
    required this.preview,
  });

  final BulkInvoicePreflightItem item;
  final _LeaseReadingControllers controllers;
  final _InvoiceDraftPreview preview;

  @override
  Widget build(BuildContext context) {
    final disabled = item.hasInvoice;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phòng ${item.roomName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.tenantName} • Tiền phòng ${formatCurrencyVnd(item.monthlyRent)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          if (item.fixedFeeAmount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Phí cố định: ${formatCurrencyVnd(item.fixedFeeAmount)}'
              ' (${item.fixedFees.map((fee) => fee.name).join(', ')})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
          if (item.invoice != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tổng hóa đơn hiện có: ${formatCurrencyVnd(item.invoice!.totalAmount)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
          if (!disabled) ...[
            const SizedBox(height: 12),
            _InvoicePreviewStrip(preview: preview),
          ],
          if (!disabled) ...[
            const SizedBox(height: 14),
            _ReadingSection(
              title: 'Chỉ số điện',
              existing: item.meterReadings.electricity,
              fields: MeterReadingFields(
                previous: controllers.electricityPrevious,
                current: controllers.electricityCurrent,
                unitPrice: controllers.electricityUnit,
                utilityType: UtilityType.electricity,
                baseline: controllers.electricityBaseline,
                validator: (field) => meterValidator(
                  field,
                  controllers.electricityPrevious,
                  controllers.electricityCurrent,
                  controllers.electricityUnit,
                ),
                summary: meterSummary(
                  controllers.electricityPrevious,
                  controllers.electricityCurrent,
                  controllers.electricityUnit,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ReadingSection(
              title: 'Chỉ số nước',
              existing: item.meterReadings.water,
              fields: MeterReadingFields(
                previous: controllers.waterPrevious,
                current: controllers.waterCurrent,
                unitPrice: controllers.waterUnit,
                utilityType: UtilityType.water,
                baseline: controllers.waterBaseline,
                validator: (field) => meterValidator(
                  field,
                  controllers.waterPrevious,
                  controllers.waterCurrent,
                  controllers.waterUnit,
                ),
                summary: meterSummary(
                  controllers.waterPrevious,
                  controllers.waterCurrent,
                  controllers.waterUnit,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.title,
    required this.existing,
    required this.fields,
  });

  final String title;
  final MeterReading? existing;
  final Widget fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        if (existing != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              'Đã có: ${existing!.previousReading} → ${existing!.currentReading} · ${formatCurrencyVnd(existing!.amount)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
          )
        else
          fields,
      ],
    );
  }
}

class _InvoicePreviewStrip extends StatelessWidget {
  const _InvoicePreviewStrip({required this.preview});

  final _InvoiceDraftPreview preview;

  @override
  Widget build(BuildContext context) {
    final color = preview.invalidCount > 0
        ? const Color(0xFFB91C1C)
        : preview.missingCount > 0
            ? const Color(0xFFD97706)
            : preview.warningCount > 0
                ? const Color(0xFFD97706)
                : AppTheme.primary;
    final label = preview.invalidCount > 0
        ? '${preview.invalidCount} mục chưa hợp lệ'
        : preview.missingCount > 0
            ? 'Thiếu ${preview.missingCount} chỉ số'
            : preview.warningCount > 0
                ? '${preview.warningCount} chỉ số cần xem lại'
                : 'Sẵn sàng tạo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatCurrencyVnd(preview.total),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AmountPill(label: 'Phòng', amount: preview.rent),
              if (preview.fixedFees > 0)
                _AmountPill(label: 'Phí cố định', amount: preview.fixedFees),
              _AmountPill(label: 'Điện', amount: preview.electricity),
              _AmountPill(label: 'Nước', amount: preview.water),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${formatCurrencyVnd(amount)}',
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BulkInvoiceItemStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BulkInvoiceItemStatus.ready => AppTheme.primary,
      BulkInvoiceItemStatus.existing => const Color(0xFF8891A8),
      BulkInvoiceItemStatus.created => const Color(0xFF10B981),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _ResultCard extends ConsumerStatefulWidget {
  const _ResultCard({
    required this.propertyId,
    required this.result,
  });

  final String propertyId;
  final BulkInvoiceGenerationResult result;

  @override
  ConsumerState<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<_ResultCard> {
  bool _sending = false;
  String? _sendMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoàn tất tạo hóa đơn tháng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đã tạo ${widget.result.createdCount} hóa đơn, bỏ qua ${widget.result.existingCount} hóa đơn đã tồn tại.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF166534)),
          ),
          if (_sendMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _sendMessage!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _sendInvoiceReminders,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Gửi nhắc Zalo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Danh sách hóa đơn'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvoiceReminders() async {
    setState(() {
      _sending = true;
      _sendMessage = null;
    });
    try {
      final result =
          await ref.read(reportsApiProvider).sendZaloInvoiceReminders(
                propertyId: widget.propertyId,
              );
      if (!mounted) return;
      setState(() {
        _sendMessage =
            'Đã gửi ${result.sent}/${result.total} tin nhắc, bỏ qua ${result.skipped}, lỗi ${result.failed}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendMessage = _friendlyReminderError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyReminderError(Object error) {
    if (error is ApiFailure) return error.message;
    return '$error';
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

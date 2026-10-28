import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/format.dart';
import '../../../models/billing.dart';
import '../../tenants/widgets/form_widgets.dart';

enum MeterReadingField { previous, current, unitPrice }

class MeterReadingFields extends StatelessWidget {
  const MeterReadingFields({
    super.key,
    required this.previous,
    required this.current,
    required this.unitPrice,
    required this.validator,
    required this.summary,
    this.utilityType,
    this.baseline,
  });

  final TextEditingController previous;
  final TextEditingController current;
  final TextEditingController unitPrice;
  final String? Function(String?) Function(MeterReadingField field) validator;
  final String? summary;
  final UtilityType? utilityType;
  final MeterReading? baseline;

  @override
  Widget build(BuildContext context) {
    final insight = meterInsight(previous, current, unitPrice, baseline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: previous,
                label: 'Cũ',
                labelColor: const Color(0xFF334155),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: validator(MeterReadingField.previous),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextField(
                controller: current,
                label: 'Mới',
                labelColor: const Color(0xFF334155),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: validator(MeterReadingField.current),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextField(
                controller: unitPrice,
                label: 'Đơn giá',
                labelColor: const Color(0xFF334155),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: validator(MeterReadingField.unitPrice),
              ),
            ),
          ],
        ),
        if (summary != null) ...[
          const SizedBox(height: 8),
          Text(
            summary!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
        if (baseline != null) ...[
          const SizedBox(height: 10),
          _PreviousReadingHint(reading: baseline!),
        ],
        if (insight != null) ...[
          const SizedBox(height: 10),
          _MeterInsightPanel(
            insight: insight,
            utilityType: utilityType ?? insight.utilityType,
          ),
        ],
      ],
    );
  }
}

enum MeterInsightLevel { normal, warning, danger }

class MeterReadingInsight {
  const MeterReadingInsight({
    required this.utilityType,
    required this.usage,
    required this.amount,
    required this.level,
    required this.message,
  });

  final UtilityType utilityType;
  final int usage;
  final int amount;
  final MeterInsightLevel level;
  final String message;
}

class _PreviousReadingHint extends StatelessWidget {
  const _PreviousReadingHint({required this.reading});

  final MeterReading reading;

  @override
  Widget build(BuildContext context) {
    final month = reading.billingMonth == null
        ? 'kỳ trước'
        : formatDate(reading.billingMonth);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 18,
            color: Color(0xFF475569),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã lấy $month: ${reading.previousReading} → '
              '${reading.currentReading}, tiêu thụ ${reading.usage}, '
              '${formatCurrencyVnd(reading.amount)}.',
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterInsightPanel extends StatelessWidget {
  const _MeterInsightPanel({
    required this.insight,
    required this.utilityType,
  });

  final MeterReadingInsight insight;
  final UtilityType utilityType;

  @override
  Widget build(BuildContext context) {
    final colors = _InsightColors.forLevel(insight.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(colors.icon, size: 18, color: colors.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${utilityType.label}: ${insight.usage} số · ${formatCurrencyVnd(insight.amount)}',
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            insight.message,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightColors {
  const _InsightColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  static _InsightColors forLevel(MeterInsightLevel level) {
    return switch (level) {
      MeterInsightLevel.normal => const _InsightColors(
          background: Color(0xFFF0FDF4),
          border: Color(0xFFBBF7D0),
          foreground: Color(0xFF166534),
          icon: Icons.check_circle_rounded,
        ),
      MeterInsightLevel.warning => const _InsightColors(
          background: Color(0xFFFFFBEB),
          border: Color(0xFFFCD34D),
          foreground: Color(0xFF92400E),
          icon: Icons.warning_amber_rounded,
        ),
      MeterInsightLevel.danger => const _InsightColors(
          background: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
          foreground: Color(0xFFB91C1C),
          icon: Icons.error_rounded,
        ),
    };
  }
}

MeterReadingInsight? meterInsight(
  TextEditingController previous,
  TextEditingController current,
  TextEditingController unitPrice, [
  MeterReading? baseline,
]) {
  if (meterBlank(previous, current, unitPrice)) return null;
  final oldValue = int.tryParse(previous.text.trim());
  final newValue = int.tryParse(current.text.trim());
  final unitValue = int.tryParse(unitPrice.text.trim());
  if (oldValue == null ||
      newValue == null ||
      unitValue == null ||
      newValue < oldValue ||
      unitValue <= 0) {
    return null;
  }

  final usage = newValue - oldValue;
  final amount = usage * unitValue;
  final baselineUsage = baseline?.usage ?? 0;
  final utilityType = baseline?.utilityType ?? UtilityType.electricity;
  if (usage == 0) {
    return MeterReadingInsight(
      utilityType: utilityType,
      usage: usage,
      amount: amount,
      level: MeterInsightLevel.normal,
      message: 'Không phát sinh tiêu thụ trong kỳ này.',
    );
  }
  if (baselineUsage > 0) {
    final increase = usage - baselineUsage;
    if (usage >= baselineUsage * 2 && increase >= 10) {
      return MeterReadingInsight(
        utilityType: utilityType,
        usage: usage,
        amount: amount,
        level: MeterInsightLevel.danger,
        message:
            'Tăng mạnh so với kỳ trước ($baselineUsage). Nên kiểm tra ảnh đồng hồ hoặc nhập lại chỉ số.',
      );
    }
    if (usage >= baselineUsage * 1.5 && increase >= 10) {
      return MeterReadingInsight(
        utilityType: utilityType,
        usage: usage,
        amount: amount,
        level: MeterInsightLevel.warning,
        message:
            'Cao hơn kỳ trước ($baselineUsage). Nên xác nhận lại trước khi tạo hóa đơn.',
      );
    }
  }
  return MeterReadingInsight(
    utilityType: utilityType,
    usage: usage,
    amount: amount,
    level: MeterInsightLevel.normal,
    message: 'Chỉ số hợp lệ, sẵn sàng tính vào hóa đơn.',
  );
}

BillingMeterReadingDraft? meterDraft(
  UtilityType type,
  TextEditingController previous,
  TextEditingController current,
  TextEditingController unitPrice,
) {
  if (meterBlank(previous, current, unitPrice)) return null;
  return BillingMeterReadingDraft(
    utilityType: type,
    previousReading: parseMeterInt(previous.text.trim()),
    currentReading: parseMeterInt(current.text.trim()),
    unitPrice: parseMeterInt(unitPrice.text.trim()),
  );
}

int parseMeterInt(String value) => int.parse(value.isEmpty ? '0' : value);

bool meterBlank(
  TextEditingController previous,
  TextEditingController current,
  TextEditingController unitPrice,
) {
  return previous.text.trim().isEmpty &&
      current.text.trim().isEmpty &&
      unitPrice.text.trim().isEmpty;
}

String? Function(String?) meterValidator(
  MeterReadingField field,
  TextEditingController previous,
  TextEditingController current,
  TextEditingController unitPrice,
) {
  return (value) {
    if (meterBlank(previous, current, unitPrice)) return null;
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Bắt buộc.';
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return 'Nhập số hợp lệ.';
    final oldValue = int.tryParse(previous.text.trim());
    final newValue = int.tryParse(current.text.trim());
    final unitValue = int.tryParse(unitPrice.text.trim());
    if (field == MeterReadingField.current &&
        oldValue != null &&
        newValue != null &&
        newValue < oldValue) {
      return 'Không nhỏ hơn chỉ số cũ.';
    }
    if (field == MeterReadingField.unitPrice &&
        unitValue != null &&
        unitValue <= 0) {
      return 'Đơn giá phải lớn hơn 0.';
    }
    return null;
  };
}

String? meterSummary(
  TextEditingController previous,
  TextEditingController current,
  TextEditingController unitPrice,
) {
  if (meterBlank(previous, current, unitPrice)) {
    return 'Bỏ trống nếu không tính mục này.';
  }
  final oldValue = int.tryParse(previous.text.trim());
  final newValue = int.tryParse(current.text.trim());
  final unitValue = int.tryParse(unitPrice.text.trim());
  if (oldValue == null ||
      newValue == null ||
      unitValue == null ||
      newValue < oldValue) {
    return null;
  }
  final usage = newValue - oldValue;
  return 'Tiêu thụ: $usage · Tạm tính: ${formatCurrencyVnd(usage * unitValue)}';
}

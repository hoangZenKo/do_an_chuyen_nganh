import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../core/utils/request_key.dart';
import '../../models/billing.dart';
import '../dashboard/dashboard_providers.dart';
import 'billing_providers.dart';

class InvoiceAdjustmentDialog extends ConsumerStatefulWidget {
  const InvoiceAdjustmentDialog({super.key, required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<InvoiceAdjustmentDialog> createState() =>
      _InvoiceAdjustmentDialogState();
}

class _InvoiceAdjustmentDialogState
    extends ConsumerState<InvoiceAdjustmentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String _kind = 'CREDIT';
  String _category = 'ADJUSTMENT';
  bool _percentage = false;
  bool _saving = false;
  String? _error;
  late String _requestKey = newRequestKey();

  int? get _basisPoints {
    final value = _amount.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  int? get _calculatedAmount => _percentage
      ? (_basisPoints == null
          ? null
          : (widget.invoice.totalAmount * _basisPoints! / 10000).round())
      : int.tryParse(_amount.text);

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _changed(String _) {
    setState(() {
      _requestKey = newRequestKey();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(billingRepositoryProvider).adjustInvoice(
            invoiceId: widget.invoice.id,
            requestKey: _requestKey,
            kind: _kind,
            category: _category,
            reason: _reason.text,
            amount: _percentage ? null : int.parse(_amount.text),
            basisPoints: _percentage ? _basisPoints : null,
          );
      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceProvider(widget.invoice.id));
      ref.invalidate(billingAgingProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ApiFailure
              ? error.message
              : 'Chưa thể phát hành phiếu. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _calculatedAmount ?? 0;
    final after =
        widget.invoice.totalAmount + (_kind == 'CREDIT' ? -amount : amount);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Điều chỉnh hóa đơn'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                      'Phiếu điều chỉnh được lưu riêng. Các dòng hóa đơn gốc không bị sửa.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _kind,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Loại điều chỉnh'),
                    items: const [
                      DropdownMenuItem(
                          value: 'CREDIT',
                          child: Text('Giảm công nợ · Credit note')),
                      DropdownMenuItem(
                          value: 'DEBIT',
                          child: Text('Tăng công nợ · Debit note')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _kind = value!;
                              _category = 'ADJUSTMENT';
                            });
                            _changed('');
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Mục đích điều chỉnh'),
                    items: {
                      'ADJUSTMENT': 'Điều chỉnh chung',
                      if (_kind == 'CREDIT') ...{
                        'DISCOUNT': 'Giảm giá',
                        'TENANT_WAIVER': 'Miễn giảm theo người thuê'
                      },
                      if (_kind == 'DEBIT') ...{
                        'SURCHARGE': 'Phụ thu',
                        'LATE_FEE': 'Phạt trả chậm'
                      },
                    }
                        .entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              enabled: entry.key != 'LATE_FEE' ||
                                  (widget.invoice.isOverdue &&
                                      widget.invoice.remainingAmount > 0),
                              child: Text(entry.value),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() => _category = value!);
                            _changed('');
                          },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tính theo phần trăm'),
                    value: _percentage,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _percentage = value;
                              _amount.clear();
                            });
                            _changed('');
                          },
                  ),
                  TextFormField(
                    controller: _amount,
                    enabled: !_saving,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: _percentage),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          _percentage ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'))
                    ],
                    decoration: InputDecoration(
                        labelText: _percentage
                            ? 'Tỷ lệ điều chỉnh (%)'
                            : 'Số tiền điều chỉnh (đ)',
                        helperText: _percentage
                            ? '0,01–100%; tối đa 2 số thập phân. Tính trên tổng hóa đơn hiện tại, làm tròn đến đồng.'
                            : null),
                    onChanged: _changed,
                    validator: (value) {
                      final amount = _calculatedAmount;
                      if (_percentage &&
                          (_basisPoints == null ||
                              _basisPoints! < 1 ||
                              _basisPoints! > 10000)) {
                        return 'Nhập tỷ lệ 0,01–100%, tối đa 2 số thập phân.';
                      }
                      if (amount == null ||
                          amount <= 0 ||
                          amount > 2147483647) {
                        return 'Nhập số tiền hợp lệ lớn hơn 0.';
                      }
                      if (_kind == 'CREDIT' &&
                          amount > widget.invoice.remainingAmount) {
                        return 'Số tiền giảm vượt quá công nợ. Hãy hoàn tác phân bổ tiền trước.';
                      }
                      if (_kind == 'DEBIT' &&
                          amount + widget.invoice.totalAmount > 2147483647) {
                        return 'Tổng hóa đơn vượt giới hạn cho phép.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration:
                        const InputDecoration(labelText: 'Lý do bắt buộc'),
                    onChanged: _changed,
                    validator: (value) => value?.trim().isEmpty ?? true
                        ? 'Vui lòng nhập lý do điều chỉnh.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text('Tổng sau điều chỉnh: ${formatCurrencyVnd(after)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Đang phát hành...' : 'Phát hành phiếu')),
        ],
      ),
    );
  }
}

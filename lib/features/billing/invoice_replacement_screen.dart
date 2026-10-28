import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../core/utils/request_key.dart';
import '../../models/billing.dart';
import '../dashboard/dashboard_providers.dart';
import 'billing_providers.dart';

const _lineKinds = {
  'RENT': 'Tiền phòng',
  'ELECTRICITY': 'Điện',
  'WATER': 'Nước',
  'SERVICE': 'Dịch vụ',
  'OTHER': 'Khoản khác',
  'DISCOUNT': 'Giảm giá',
  'SURCHARGE': 'Phụ thu',
};

class InvoiceReplacementScreen extends ConsumerStatefulWidget {
  const InvoiceReplacementScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<InvoiceReplacementScreen> createState() =>
      _InvoiceReplacementScreenState();
}

class _InvoiceReplacementScreenState
    extends ConsumerState<InvoiceReplacementScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final List<_LineDraft> _lines;
  late DateTime? _dueDate;
  bool _saving = false;
  String? _error;
  String? _fingerprint;
  String? _requestKey;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _dueDate = invoice.dueDate;
    _lines = invoice.lineItems.map((line) {
      final quantity =
          line.quantity > 0 && line.quantity * line.unitPrice == line.amount
              ? line.quantity
              : 1;
      final kind = line.amount < 0 ? 'DISCOUNT' : line.kind.toUpperCase();
      return _LineDraft(
        kind: _lineKinds.containsKey(kind) ? kind : 'OTHER',
        description: line.description,
        quantity: quantity,
        unit: line.unit,
        price: quantity == line.quantity ? line.unitPrice : line.amount,
      );
    }).toList();
    if (_lines.isEmpty) {
      for (final item in [
        ('RENT', 'Tiền phòng', invoice.rentAmount),
        ('ELECTRICITY', 'Tiền điện', invoice.electricityAmount),
        ('WATER', 'Tiền nước', invoice.waterAmount),
        (
          invoice.otherAmount < 0 ? 'DISCOUNT' : 'OTHER',
          'Khoản khác',
          invoice.otherAmount
        ),
      ]) {
        if (item.$3 != 0) {
          _lines.add(
              _LineDraft(kind: item.$1, description: item.$2, price: item.$3));
        }
      }
      if (_lines.isEmpty) {
        _lines.add(_LineDraft());
      }
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  int get _total => _lines.fold(0, (sum, line) => sum + line.total);

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_lines.isEmpty || _total < 0 || _total > 2147483647) {
      setState(() => _error =
          'Cần ít nhất một dòng phí và tổng tiền từ 0 đến 2.147.483.647 đ.');
      return;
    }
    final lines = _lines.map((line) => line.payload).toList();
    final dueDate = _dueDate?.toUtc().toIso8601String();
    final fingerprint =
        jsonEncode([widget.invoice.id, _reason.text.trim(), dueDate, lines]);
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _requestKey = newRequestKey();
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final invoice = await ref.read(billingRepositoryProvider).replaceInvoice(
            invoiceId: widget.invoice.id,
            requestKey: _requestKey!,
            reason: _reason.text,
            lines: lines,
            dueDate: dueDate,
          );
      ref.invalidate(invoiceProvider(widget.invoice.id));
      ref.invalidate(invoicesProvider);
      ref.invalidate(billingAgingProvider);
      ref.invalidate(dashboardMetricsProvider);
      if (mounted) Navigator.of(context).pop(invoice);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ApiFailure
              ? error.message
              : 'Chưa thể thay thế hóa đơn. Kiểm tra kết nối và thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Tạo hóa đơn thay thế')),
          body: !widget.invoice.canReplace
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'Không thể thay thế hóa đơn này. Hóa đơn có lịch sử thanh toán cần dùng credit / debit note.')))
              : Form(
                  key: _form,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              '${widget.invoice.roomName ?? 'Phòng'} · ${formatMonth(widget.invoice.billingMonth)}',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          const Text(
                              'Phát hành sẽ hủy hóa đơn gốc có lý do và tạo phiên bản mới. Các dòng trên hóa đơn gốc không bị sửa. Hãy kiểm tra tổng tiền trước khi xác nhận.'),
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: _reason,
                              enabled: !_saving,
                              maxLength: 500,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                  labelText: 'Lý do thay thế *'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Nhập lý do thay thế.'
                                      : null),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Ngày đến hạn'),
                              subtitle: Text(_dueDate == null
                                  ? 'Chưa đặt'
                                  : formatDate(_dueDate)),
                              trailing:
                                  const Icon(Icons.calendar_today_outlined),
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final now = DateTime.now();
                                      final current = _dueDate ?? now;
                                      final date = await showDatePicker(
                                          context: context,
                                          initialDate: current,
                                          firstDate: DateTime(current.year - 1),
                                          lastDate: DateTime(now.year + 20));
                                      if (date != null && mounted) {
                                        setState(() => _dueDate = DateTime.utc(
                                            date.year, date.month, date.day));
                                      }
                                    }),
                          for (final line in _lines) ...[
                            const Divider(height: 32),
                            _lineEditor(line),
                          ],
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                              onPressed: _saving || _lines.length >= 100
                                  ? null
                                  : () =>
                                      setState(() => _lines.add(_LineDraft())),
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm dòng phí')),
                          const SizedBox(height: 20),
                          Text(
                              'Hóa đơn gốc: ${formatCurrencyVnd(widget.invoice.totalAmount)}'),
                          Text('Tổng thay thế: ${formatCurrencyVnd(_total)}',
                              style: Theme.of(context).textTheme.titleLarge),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              onPressed: _saving ? null : _submit,
                              icon: const Icon(Icons.published_with_changes),
                              label: Text(_saving
                                  ? 'Đang phát hành…'
                                  : 'Hủy bản gốc và phát hành bản thay thế')),
                        ],
                      ))),
        ),
      );

  Widget _lineEditor(_LineDraft line) => Column(
        key: ObjectKey(line),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: DropdownButtonFormField<String>(
              value: line.kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loại dòng phí'),
              items: _lineKinds.entries
                  .map((entry) => DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => line.kind = value!),
            )),
            IconButton(
                tooltip: 'Xóa dòng phí',
                onPressed: _saving || _lines.length == 1
                    ? null
                    : () {
                        setState(() => _lines.remove(line));
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => line.dispose());
                      },
                icon: const Icon(Icons.delete_outline)),
          ]),
          const SizedBox(height: 12),
          TextFormField(
              controller: line.description,
              enabled: !_saving,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Nội dung *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nhập nội dung.'
                  : null),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: TextFormField(
                    controller: line.quantity,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số lượng *'),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final quantity = int.tryParse(value ?? '');
                      return quantity == null ||
                              quantity < 1 ||
                              quantity > 2147483647
                          ? 'Số nguyên dương.'
                          : null;
                    })),
            const SizedBox(width: 12),
            Expanded(
                child: TextFormField(
                    controller: line.unit,
                    enabled: !_saving,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: 'Đơn vị *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập đơn vị.'
                        : null)),
          ]),
          TextFormField(
              controller: line.price,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                  labelText: 'Đơn giá (đ) *',
                  helperText: 'Giảm giá dùng số âm; các dòng khác không âm.'),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final price = int.tryParse(value ?? '');
                if (price == null ||
                    price.abs() > 2147483647 ||
                    line.total.abs() > 2147483647) {
                  return 'Đơn giá/thành tiền ngoài giới hạn.';
                }
                if ((line.kind == 'DISCOUNT') != (price < 0)) {
                  return 'Chỉ dòng giảm giá được có đơn giá âm.';
                }
                return null;
              }),
          const SizedBox(height: 8),
          Text('Thành tiền: ${formatCurrencyVnd(line.total)}'),
        ],
      );
}

class _LineDraft {
  _LineDraft(
      {this.kind = 'OTHER',
      String description = '',
      int quantity = 1,
      String unit = 'lan',
      int price = 0})
      : description = TextEditingController(text: description),
        quantity = TextEditingController(text: '$quantity'),
        unit = TextEditingController(text: unit),
        price = TextEditingController(text: '$price');

  String kind;
  final TextEditingController description, quantity, unit, price;
  int get total =>
      (int.tryParse(quantity.text) ?? 0) * (int.tryParse(price.text) ?? 0);
  Map<String, dynamic> get payload => {
        'kind': kind,
        'description': description.text.trim(),
        'quantity': int.parse(quantity.text),
        'unit': unit.text.trim(),
        'unitPrice': int.parse(price.text)
      };
  void dispose() {
    for (final controller in [description, quantity, unit, price]) {
      controller.dispose();
    }
  }
}

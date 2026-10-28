import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/billing_receipt.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_navigation.dart';
import '../reports/reports_providers.dart';
import 'billing_providers.dart';

class BillingReceiptsScreen extends ConsumerWidget {
  const BillingReceiptsScreen(
      {super.key, required this.tenantId, required this.tenantName});

  final String tenantId;
  final String tenantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final receipts = ref.watch(billingReceiptsProvider(tenantId));
    final invoices = ref.watch(billingTenantInvoicesProvider(tenantId));
    final canCollect = sessionHasPermission(session, 'billing.record_payment');
    final canRelease = sessionHasPermission(session, 'billing.reverse_payment');
    final canRefund = sessionHasPermission(session, 'billing.refund');

    void reload() {
      ref.invalidate(billingReceiptsProvider(tenantId));
      ref.invalidate(billingTenantInvoicesProvider(tenantId));
    }

    Future<void> command(ReceiptOperation operation,
        {BillingReceipt? receipt, BillingAllocation? allocation}) async {
      await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => BillingReceiptCommandDialog(
                operation: operation,
                tenantId: tenantId,
                invoices: invoices.value ?? [],
                receipt: receipt,
                allocation: allocation,
              ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Khoản thu & phân bổ'), actions: [
        IconButton(
            tooltip: 'Tải lại',
            onPressed: reload,
            icon: const Icon(Icons.refresh))
      ]),
      body: receipts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_message(error), textAlign: TextAlign.center),
                  TextButton(onPressed: reload, child: const Text('Thử lại')),
                ]))),
        data: (rows) => RefreshIndicator(
          onRefresh: () async {
            reload();
            await ref.read(billingReceiptsProvider(tenantId).future);
          },
          child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(tenantName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'Một khoản thu có thể phân bổ cho nhiều hóa đơn của cùng người thuê. Tiền dư được giữ lại để phân bổ sau hoặc ghi nhận hoàn tiền.'),
                const SizedBox(height: 16),
                if (canCollect)
                  Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: invoices.hasValue
                            ? () => command(ReceiptOperation.create)
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Ghi nhận khoản thu'),
                      )),
                if (invoices.isLoading) const LinearProgressIndicator(),
                if (invoices.hasError)
                  TextButton(
                      onPressed: reload,
                      child: const Text('Chưa tải được hóa đơn. Thử lại')),
                const SizedBox(height: 16),
                const Text('Chưa phân bổ trong danh sách'),
                Text(
                    formatCurrencyVnd(rows.fold<int>(0,
                        (total, receipt) => total + receipt.availableAmount)),
                    style: Theme.of(context).textTheme.titleLarge),
                const Text('Danh sách hiển thị tối đa 200 khoản thu gần nhất.'),
                const Divider(height: 32),
                if (rows.isEmpty)
                  const Text(
                      'Chưa có khoản thu. Các thanh toán cũ vẫn hiển thị trong lịch sử từng hóa đơn.'),
                for (final receipt in rows)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                        '${formatCurrencyVnd(receipt.amount)} · ${receipt.method.label}'),
                    subtitle: Text(
                        '${formatDate(receipt.paidAt)} · ${receipt.reference}\nChưa phân bổ: ${formatCurrencyVnd(receipt.availableAmount)}'),
                    childrenPadding: const EdgeInsets.only(bottom: 20),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText('Mã khoản thu: ${receipt.id}'),
                      Text(
                          'Đã hoàn: ${formatCurrencyVnd(receipt.refundedAmount)}'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (canCollect && receipt.availableAmount > 0)
                          OutlinedButton(
                              onPressed: invoices.hasValue
                                  ? () => command(ReceiptOperation.allocate,
                                      receipt: receipt)
                                  : null,
                              child: const Text('Phân bổ tiền dư')),
                        if (canRefund && receipt.availableAmount > 0)
                          OutlinedButton(
                              onPressed: () => command(ReceiptOperation.refund,
                                  receipt: receipt),
                              child: const Text('Ghi nhận hoàn tiền')),
                      ]),
                      if (receipt.allocations.isNotEmpty)
                        const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 8),
                            child: Text('Lịch sử phân bổ')),
                      for (final allocation in receipt.allocations)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${formatCurrencyVnd(allocation.amount)} · ${allocation.releasedAt == null ? 'Đang phân bổ' : 'Đã gỡ phân bổ'}'),
                          subtitle: Text(
                              '${_invoiceName(invoices.value ?? [], allocation.invoiceId)}${allocation.releaseReason == null ? '' : '\n${allocation.releaseReason}'}'),
                          trailing: canRelease && allocation.releasedAt == null
                              ? IconButton(
                                  tooltip: 'Gỡ phân bổ về tiền dư',
                                  icon: const Icon(Icons.undo),
                                  onPressed: () => command(
                                      ReceiptOperation.release,
                                      receipt: receipt,
                                      allocation: allocation))
                              : null,
                        ),
                      for (final refund in receipt.refunds)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                'Hoàn ${formatCurrencyVnd(refund.amount)} · ${formatDate(refund.createdAt)}'),
                            subtitle:
                                Text('${refund.reference}\n${refund.reason}')),
                    ],
                  ),
              ]),
        ),
      ),
    );
  }
}

enum ReceiptOperation { create, allocate, refund, release }

class BillingReceiptCommandDialog extends ConsumerStatefulWidget {
  const BillingReceiptCommandDialog(
      {super.key,
      required this.operation,
      required this.tenantId,
      required this.invoices,
      this.receipt,
      this.allocation});
  final ReceiptOperation operation;
  final String tenantId;
  final List<Invoice> invoices;
  final BillingReceipt? receipt;
  final BillingAllocation? allocation;

  @override
  ConsumerState<BillingReceiptCommandDialog> createState() =>
      _BillingReceiptCommandDialogState();
}

class _BillingReceiptCommandDialogState
    extends ConsumerState<BillingReceiptCommandDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _reason = TextEditingController();
  final Map<String, TextEditingController> _allocations = {};
  PaymentMethod _method = PaymentMethod.bankTransfer;
  bool _saving = false;
  String? _error;
  String? _lastPayload;
  String _requestKey = '';
  late final String? _sessionIdentity = ref.read(sessionIdentityProvider);

  bool get _allocates =>
      widget.operation == ReceiptOperation.create ||
      widget.operation == ReceiptOperation.allocate;
  int get _available => widget.operation == ReceiptOperation.create
      ? int.tryParse(_amount.text) ?? 0
      : widget.receipt!.availableAmount;
  int get _allocated => _allocations.values.fold(
      0, (total, controller) => total + (int.tryParse(controller.text) ?? 0));
  String get _title => switch (widget.operation) {
        ReceiptOperation.create => 'Ghi nhận khoản thu',
        ReceiptOperation.allocate => 'Phân bổ tiền dư',
        ReceiptOperation.refund => 'Ghi nhận hoàn tiền',
        ReceiptOperation.release => 'Gỡ phân bổ',
      };

  @override
  void initState() {
    super.initState();
    for (final invoice in widget.invoices.where((invoice) =>
        invoice.status != InvoiceStatus.cancelled &&
        invoice.remainingAmount > 0 &&
        !invoice.isDemo)) {
      _allocations[invoice.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _reason.dispose();
    for (final controller in _allocations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_sessionIdentity != ref.read(sessionIdentityProvider)) return;
    if (_allocates &&
        (_allocated > _available ||
            (widget.operation == ReceiptOperation.allocate &&
                _allocated == 0))) {
      setState(() => _error = _allocated > _available
          ? 'Tổng phân bổ vượt số tiền có thể dùng.'
          : 'Nhập số tiền cho ít nhất một hóa đơn.');
      return;
    }
    final lines = [
      for (final entry in _allocations.entries)
        if ((int.tryParse(entry.value.text) ?? 0) > 0)
          {'invoiceId': entry.key, 'amount': int.parse(entry.value.text)}
    ];
    final payload = jsonEncode([
      widget.operation.name,
      _amount.text,
      _method.name,
      _reference.text.trim(),
      _reason.text.trim(),
      lines
    ]);
    if (_lastPayload != payload) {
      _requestKey = _newKey();
      _lastPayload = payload;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(billingRepositoryProvider);
      switch (widget.operation) {
        case ReceiptOperation.create:
          await repository.createReceipt(
              requestKey: _requestKey,
              tenantId: widget.tenantId,
              amount: int.parse(_amount.text),
              reference: _reference.text,
              allocations: lines,
              method: _method);
        case ReceiptOperation.allocate:
          await repository.allocateReceipt(
              receiptId: widget.receipt!.id,
              requestKey: _requestKey,
              allocations: lines);
        case ReceiptOperation.refund:
          await repository.refundReceipt(
              receiptId: widget.receipt!.id,
              requestKey: _requestKey,
              amount: int.parse(_amount.text),
              reference: _reference.text,
              reason: _reason.text);
        case ReceiptOperation.release:
          await repository.releaseAllocation(
              receiptId: widget.receipt!.id,
              allocationId: widget.allocation!.id,
              requestKey: _requestKey,
              reason: _reason.text);
      }
      if (!mounted) return;
      ref.invalidate(billingReceiptsProvider(widget.tenantId));
      ref.invalidate(billingTenantInvoicesProvider(widget.tenantId));
      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceProvider);
      ref.invalidate(billingAgingProvider);
      ref.invalidate(billingRemindersProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionIdentity != ref.watch(sessionIdentityProvider)) {
      return AlertDialog(
          title: const Text('Phiên làm việc đã thay đổi'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'))
          ]);
    }
    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(_title),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.operation == ReceiptOperation.release)
                              const Text(
                                  'Hóa đơn sẽ ghi nhận một bút toán hoàn tác. Tiền trở về số dư chưa phân bổ; thao tác này không tự chuyển tiền qua ngân hàng.'),
                            if (widget.operation == ReceiptOperation.refund)
                              Text(
                                  'Chỉ hoàn từ tiền chưa phân bổ: ${formatCurrencyVnd(_available)}. Đây là ghi nhận kế toán; cần thực hiện chuyển tiền riêng.'),
                            if (widget.operation == ReceiptOperation.create ||
                                widget.operation ==
                                    ReceiptOperation.refund) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _amount,
                                  enabled: !_saving,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: InputDecoration(
                                      labelText: widget.operation ==
                                              ReceiptOperation.refund
                                          ? 'Số tiền hoàn (đ)'
                                          : 'Tổng tiền thực nhận (đ)'),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    final amount = int.tryParse(value ?? '');
                                    if (amount == null ||
                                        amount < 1 ||
                                        amount > 2147483647) {
                                      return 'Nhập số tiền từ 1 đến 2.147.483.647 đ.';
                                    }
                                    if (widget.operation ==
                                            ReceiptOperation.refund &&
                                        amount > _available) {
                                      return 'Số tiền hoàn vượt tiền chưa phân bổ.';
                                    }
                                    return null;
                                  }),
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _reference,
                                  enabled: !_saving,
                                  maxLength: 200,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Mã giao dịch / biên nhận bắt buộc'),
                                  validator: (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Vui lòng nhập mã tham chiếu.'
                                          : null),
                            ],
                            if (widget.operation == ReceiptOperation.create)
                              DropdownButtonFormField<PaymentMethod>(
                                  value: _method,
                                  decoration: const InputDecoration(
                                      labelText: 'Phương thức nhận tiền'),
                                  items: PaymentMethod.values
                                      .map((method) => DropdownMenuItem(
                                          value: method,
                                          child: Text(method.label)))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (value) =>
                                          setState(() => _method = value!)),
                            if (_allocates) ...[
                              const SizedBox(height: 20),
                              Text('Phân bổ cho hóa đơn',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const Text(
                                  'Để trống để chưa phân bổ. Số tiền trả thiếu vẫn được ghi nhận theo từng hóa đơn.'),
                              for (final invoice in widget.invoices.where(
                                  (invoice) =>
                                      _allocations.containsKey(invoice.id)))
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: TextFormField(
                                      controller: _allocations[invoice.id],
                                      enabled: !_saving,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                          labelText:
                                              '${invoice.roomName ?? 'Phòng'} · ${formatMonth(invoice.billingMonth)}',
                                          helperText:
                                              'Còn nợ ${formatCurrencyVnd(invoice.remainingAmount)}'),
                                      validator: (value) {
                                        final amount = value?.isEmpty ?? true
                                            ? 0
                                            : int.tryParse(value!);
                                        return amount == null ||
                                                amount < 0 ||
                                                amount > invoice.remainingAmount
                                            ? 'Số phân bổ không được vượt công nợ.'
                                            : null;
                                      },
                                    )),
                              const SizedBox(height: 16),
                              Text(
                                  'Đã phân bổ: ${formatCurrencyVnd(_allocated)}'),
                              Text(
                                  'Tiền dư còn lại: ${formatCurrencyVnd(_available - _allocated)}'),
                            ],
                            if (widget.operation == ReceiptOperation.release ||
                                widget.operation ==
                                    ReceiptOperation.refund) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _reason,
                                  enabled: !_saving,
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 500,
                                  decoration: const InputDecoration(
                                      labelText: 'Lý do bắt buộc'),
                                  validator: (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Vui lòng nhập lý do.'
                                          : null),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error))
                            ],
                          ])))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Đang lưu...' : _title))
          ],
        ));
  }
}

String _message(Object error) => error is ApiFailure
    ? error.message
    : 'Chưa thể tải hoặc lưu dữ liệu. Vui lòng thử lại.';

String _invoiceName(List<Invoice> invoices, String id) {
  for (final invoice in invoices) {
    if (invoice.id == id) {
      return '${invoice.roomName ?? 'Phòng'} · ${formatMonth(invoice.billingMonth)}';
    }
  }
  return 'Hóa đơn $id';
}

String _newKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

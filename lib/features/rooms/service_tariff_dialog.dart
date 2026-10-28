import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../models/room.dart';
import '../billing/billing_providers.dart';
import 'room_providers.dart';

class ServiceTariffDialog extends ConsumerStatefulWidget {
  const ServiceTariffDialog({super.key, required this.roomId, this.fee});

  final String roomId;
  final RoomServiceFee? fee;

  @override
  ConsumerState<ServiceTariffDialog> createState() =>
      _ServiceTariffDialogState();
}

class _ServiceTariffDialogState extends ConsumerState<ServiceTariffDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late final TextEditingController _month;
  late final TextEditingController _note;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fee = widget.fee;
    final latest = fee?.versions.firstOrNull;
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    var start = DateTime.utc(now.year, now.month + (fee == null ? 0 : 1), 1);
    final previous = latest?.effectiveFrom;
    if (previous != null && !previous.isBefore(start)) {
      start = DateTime.utc(previous.year, previous.month + 1, 1);
    }
    _name = TextEditingController(text: latest?.name ?? fee?.name ?? '');
    _amount =
        TextEditingController(text: '${latest?.amount ?? fee?.amount ?? 0}');
    _unit = TextEditingController(text: latest?.unit ?? fee?.unit ?? 'tháng');
    _month = TextEditingController(
        text: '${start.year}-${start.month.toString().padLeft(2, '0')}');
    _note = TextEditingController(text: latest?.note ?? fee?.note ?? '');
    _active = latest?.isActive ?? fee?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in [_name, _amount, _unit, _month, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'amount': int.parse(_amount.text),
        'unit': _unit.text.trim(),
        'note': _note.text.trim(),
        'effectiveFrom': '${_month.text.trim()}-01',
      };
      final api = ref.read(roomApiProvider);
      final fee = widget.fee;
      if (fee == null) {
        await api.createServiceFee(widget.roomId, payload);
      } else {
        await api.updateServiceFee(widget.roomId, fee.id, {
          ...payload,
          'isActive': _active,
          'expectedVersion': fee.version,
        });
      }
      if (!mounted) return;
      ref.invalidate(roomServiceFeesProvider(widget.roomId));
      ref.invalidate(billingActiveLeasesProvider);
      ref.invalidate(billingLeasesForMonthProvider);
      ref.invalidate(bulkInvoicePreflightProvider);
      ref.invalidate(billingAutomationPreviewProvider);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error is ApiFailure ? error.code : null) {
          'TARIFF_VERSION_CHANGED' =>
            'Biểu phí đã thay đổi. Đóng biểu mẫu và tải lại dữ liệu trước khi lưu.',
          'TARIFF_DATE_CONFLICT' =>
            'Tháng áp dụng phải sau phiên bản mới nhất.',
          'TARIFF_PERIOD_INVOICED' =>
            'Đã có hóa đơn trong hoặc sau kỳ này. Hãy chọn tháng muộn hơn.',
          'TARIFF_PERIOD_CLOSED' =>
            'Kỳ áp dụng đã bị khóa. Hãy chọn tháng sau kỳ đã khóa.',
          'TARIFF_RETROACTIVE' =>
            'Không thể thay đổi biểu phí cho tháng đã qua.',
          _ => 'Không lưu được biểu phí. Kiểm tra kết nối và thử lại.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(widget.fee == null
              ? 'Thêm biểu phí dịch vụ'
              : 'Tạo phiên bản v${widget.fee!.version + 1}'),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Phí cố định tính một đơn vị mỗi tháng. Hóa đơn đã phát hành không thay đổi khi biểu phí đổi.'),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 80,
                          decoration:
                              const InputDecoration(labelText: 'Tên dịch vụ'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Nhập tên dịch vụ'
                                  : null),
                      TextFormField(
                          controller: _amount,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Đơn giá (VND)'),
                          validator: (value) {
                            final amount = int.tryParse(value ?? '');
                            return amount == null ||
                                    amount < 0 ||
                                    amount > 2147483647
                                ? 'Nhập số tiền từ 0 đến 2.147.483.647'
                                : null;
                          }),
                      TextFormField(
                          controller: _unit,
                          enabled: !_saving,
                          maxLength: 20,
                          decoration:
                              const InputDecoration(labelText: 'Đơn vị tính'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Nhập đơn vị tính'
                                  : null),
                      TextFormField(
                          controller: _month,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Tháng bắt đầu áp dụng',
                              hintText: 'YYYY-MM'),
                          validator: (value) =>
                              !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$')
                                      .hasMatch(value?.trim() ?? '')
                                  ? 'Nhập tháng theo YYYY-MM'
                                  : null),
                      if (widget.fee != null)
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Thu phí từ kỳ này'),
                            subtitle: const Text(
                                'Tắt để lên lịch ngừng thu và giữ lịch sử.'),
                            value: _active,
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _active = value)),
                      TextFormField(
                          controller: _note,
                          enabled: !_saving,
                          maxLength: 500,
                          decoration: const InputDecoration(
                              labelText: 'Ghi chú / lý do thay đổi')),
                      if (_error != null)
                        Semantics(
                            liveRegion: true,
                            child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)))),
                    ]),
              ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang lưu…' : 'Lưu biểu phí')),
          ],
        ),
      );
}

Future<void> showServiceTariffHistory(
    BuildContext context, RoomServiceFee fee) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final month = DateTime.utc(now.year, now.month, 1);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
        child: ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lịch sử · ${fee.name}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (fee.versions.isEmpty)
                const Text('Chưa có lịch sử phiên bản.'),
              ...fee.versions.map((version) {
                final future = version.effectiveFrom?.isAfter(month) ?? false;
                final ended = version.effectiveTo != null &&
                    !version.effectiveTo!.isAfter(month);
                final status = future
                    ? 'Đã lên lịch'
                    : ended
                        ? 'Đã hết hiệu lực'
                        : version.isActive
                            ? 'Đang thu'
                            : 'Đã ngừng thu';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  isThreeLine: true,
                  title: Text('v${version.version} · ${version.name}'),
                  subtitle: Text(
                      '${formatCurrencyVnd(version.amount)} / ${version.unit}\nTừ ${version.effectiveFrom?.toIso8601String().substring(0, 7) ?? '—'} · $status'),
                );
              }),
            ],
          )),
    )),
  );
}

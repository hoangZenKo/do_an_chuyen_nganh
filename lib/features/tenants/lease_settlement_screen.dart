import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../data/tenants/lease_settlement_api.dart';
import '../../models/lease.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../operations/p1_providers.dart';
import '../rooms/room_providers.dart';
import 'tenant_providers.dart';

final leaseSettlementApiProvider = Provider<LeaseSettlementApi>((ref) =>
    LeaseSettlementApi(ref.watch(sessionDioProvider).client,
        ownerId: ref.watch(sessionIdentityProvider)));
final leaseSettlementAccessProvider = Provider<bool>((ref) =>
    ref.watch(sessionControllerProvider).session?.user.role == 'landlord');

String _requestKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class LeaseSettlementScreen extends ConsumerStatefulWidget {
  const LeaseSettlementScreen({super.key, required this.lease});
  final Lease lease;
  @override
  ConsumerState<LeaseSettlementScreen> createState() => _LeaseSettlementState();
}

class _LeaseSettlementState extends ConsumerState<LeaseSettlementScreen> {
  final _form = GlobalKey<FormState>();
  final _inputs = <String, TextEditingController>{
    for (final key in [
      'moveOutDate',
      'finalElectricity',
      'electricityUnitPrice',
      'finalWater',
      'waterUnitPrice',
      'damage',
      'cleaning',
      'other',
      'note'
    ])
      key: TextEditingController(),
  };
  late final String? _owner;
  late final LeaseSettlementApi _api;
  bool _loading = true, _busy = false;
  String? _error;
  Map<String, dynamic>? _record, _preview, _confirmation, _refund;
  bool get _active =>
      mounted &&
      _owner != null &&
      ref.read(sessionIdentityProvider) == _owner &&
      ref.read(leaseSettlementAccessProvider);

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _api = ref.read(leaseSettlementApiProvider);
    final today = DateTime.now().toUtc().add(const Duration(hours: 7));
    _inputs['moveOutDate']!.text =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() {
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!_active) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get(widget.lease.id);
      if (mounted && _active) {
        setState(() {
          _record = result;
          _preview = null;
          _confirmation = null;
        });
      }
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _loading = false);
    }
  }

  void _edited(String _) {
    if (_preview != null) {
      setState(() {
        _preview = null;
        _confirmation = null;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_active || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted && _active) {
        setState(() {
          _error = error is ApiFailure
              ? error.message
              : 'Không thể hoàn tất. Kiểm tra kết nối và thử lại.';
          if (error is ApiFailure && error.statusCode == 409) {
            _preview = null;
            _confirmation = null;
            _refund = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      if (_active) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _prepare() async {
    if (!_form.currentState!.validate()) return;
    final input = <String, dynamic>{
      'moveOutDate': _inputs['moveOutDate']!.text.trim(),
      'note': _inputs['note']!.text.trim(),
      for (final key in [
        'finalElectricity',
        'electricityUnitPrice',
        'finalWater',
        'waterUnitPrice'
      ])
        if (_inputs[key]!.text.isNotEmpty) key: int.parse(_inputs[key]!.text),
      'lines': [
        for (final entry in {
          'damage': ['DAMAGE', 'Bồi thường hư hỏng'],
          'cleaning': ['CLEANING', 'Phí vệ sinh'],
          'other': ['OTHER', 'Chi phí khác']
        }.entries)
          if ((int.tryParse(_inputs[entry.key]!.text) ?? 0) > 0)
            {
              'kind': entry.value[0],
              'description': entry.value[1],
              'amount': int.parse(_inputs[entry.key]!.text)
            },
      ],
    };
    await _run(() async {
      final result = await _api.preview(widget.lease.id, input);
      if (!_active) return;
      final fingerprint = result['previewFingerprint'];
      if (fingerprint is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
        throw const ApiFailure(message: 'Preview chưa có mã xác thực hợp lệ.');
      }
      setState(() {
        _preview = result;
        _confirmation = {
          ...input,
          'previewFingerprint': fingerprint,
          'idempotencyKey': _requestKey()
        };
      });
    });
  }

  Future<void> _confirm() async {
    if (!_active || _confirmation == null || _busy) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Xác nhận trả phòng?'),
              content: const Text(
                  'Hợp đồng sẽ kết thúc và phòng chuyển sang chờ kiểm tra, sửa chữa, vệ sinh. Quyết toán không thể sửa trực tiếp. Chưa có tiền hoàn cọc nào được chuyển.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xác nhận trả phòng'))
              ],
            ));
    if (confirmed != true || !_active) return;
    await _run(() async {
      final result = await _api.confirm(widget.lease.id, _confirmation!);
      if (!_active) return;
      setState(() {
        _record = result;
        _preview = null;
        _confirmation = null;
      });
      _refresh();
    });
  }

  void _refresh() {
    ref.invalidate(tenantLeasesProvider(widget.lease.tenantId));
    ref.invalidate(tenantOverviewProvider(widget.lease.tenantId));
    ref.invalidate(roomLeasesProvider(widget.lease.roomId));
    ref.invalidate(roomsProvider);
    ref.invalidate(dashboardMetricsProvider);
    ref.invalidate(p1OperationsApiProvider);
  }

  Future<void> _recordRefund() async {
    if (!_active || _busy || _record == null) return;
    if (_refund == null) {
      final result = await showDialog<Map<String, String>>(
          context: context, builder: (_) => const _RefundDialog());
      if (!_active || result == null) return;
      _refund = {
        ...result,
        'version': _record!['version'],
        'idempotencyKey': _requestKey()
      };
    }
    await _run(() async {
      final result = await _api.refund(widget.lease.id, _refund!);
      if (!_active) return;
      setState(() {
        _record = result;
        _refund = null;
      });
      _refresh();
    });
  }

  Widget _field(String key, String label, {bool numeric = true}) =>
      TextFormField(
        key: ValueKey(key),
        controller: _inputs[key],
        enabled: !_busy,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters:
            numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLines: key == 'note' ? 3 : 1,
        maxLength: key == 'note' ? 1000 : null,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        onChanged: _edited,
        validator: (value) {
          if (key == 'moveOutDate') {
            final parsed = DateTime.tryParse(value ?? '');
            return parsed == null ||
                    parsed.toIso8601String().substring(0, 10) != value ||
                    !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value ?? '')
                ? 'Nhập YYYY-MM-DD hợp lệ.'
                : null;
          }
          if (key == 'note') {
            return (value?.trim().length ?? 0) < 10
                ? 'Nêu lý do và các chi phí, tối thiểu 10 ký tự.'
                : null;
          }
          if (value == null || value.isEmpty) return null;
          final number = int.tryParse(value);
          return number == null || number < 0 || number > 2147483647
              ? 'Nhập số nguyên từ 0 đến 2.147.483.647.'
              : null;
        },
      );

  Widget _amount(String title, Object? raw, {bool emphasis = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(title,
                  style: emphasis
                      ? Theme.of(context).textTheme.titleMedium
                      : null)),
          const SizedBox(width: 16),
          Flexible(
              child: Text(formatCurrencyVnd((raw as num?)?.toInt() ?? 0),
                  textAlign: TextAlign.end,
                  style: emphasis
                      ? Theme.of(context).textTheme.titleMedium
                      : null)),
        ]),
      );

  Widget _summary(Map<String, dynamic> data, {required bool confirmed}) {
    final snapshot = data['snapshot'] is Map ? data['snapshot'] as Map : data;
    final lines = (data['lines'] as List? ?? []).whereType<Map>();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  confirmed ? 'Quyết toán đã xác nhận' : 'Xem trước quyết toán',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final line in lines)
                _amount('${line['description']}', line['amount']),
              const Divider(),
              _amount('Tổng chi phí mới', data['totalCharges'], emphasis: true),
              _amount('Cọc đang giữ trước quyết toán', data['depositBalance']),
              _amount('Cấn trừ chi phí mới từ cọc', data['depositApplied']),
              _amount('Phải thu thêm cho quyết toán', data['balanceDue'],
                  emphasis: true),
              _amount('Công nợ hóa đơn cũ (riêng)',
                  data['outstandingInvoiceAmount']),
              _amount('Phải hoàn cọc', data['refundAmount'], emphasis: true),
              for (final warning in snapshot['warnings'] as List? ?? [])
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('$warning')),
              const SizedBox(height: 16),
              if (!confirmed)
                FilledButton.icon(
                    onPressed: _busy ? null : _confirm,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Xác nhận trả phòng')),
              if (confirmed && data['refundStatus'] == 'PENDING') ...[
                const Text(
                    'Chờ hoàn cọc. Chỉ ghi nhận sau khi tiền đã được chuyển hoặc trao cho người thuê.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: _busy ? null : _recordRefund,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Ghi nhận đã hoàn cọc')),
              ],
              if (confirmed && data['refundStatus'] == 'PAID')
                Text('Đã ghi nhận hoàn cọc · ${data['refundReference']}'),
              if (confirmed && data['refundStatus'] == 'NOT_DUE')
                const Text('Không phát sinh hoàn cọc.'),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(sessionIdentityProvider) == _owner &&
        _owner != null &&
        ref.watch(leaseSettlementAccessProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trả phòng & quyết toán')),
      body: !visible
          ? const Center(
              child: Text('Phiên đăng nhập hoặc quyền truy cập đã thay đổi.'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              Text(
                                  'Phòng ${widget.lease.roomName ?? widget.lease.roomId}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                              Text(widget.lease.tenantName ?? 'Hợp đồng thuê'),
                              const SizedBox(height: 16),
                              if (_busy) const LinearProgressIndicator(),
                              if (_error != null) ...[
                                Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                                TextButton(
                                    onPressed: _busy ? null : _load,
                                    child: const Text('Tải lại quyết toán'))
                              ],
                              if (_record != null)
                                _summary(_record!, confirmed: true)
                              else if (widget.lease.status !=
                                  LeaseStatus.active)
                                const Text(
                                    'Hợp đồng đã kết thúc theo luồng cũ, chưa có quyết toán được lưu.')
                              else
                                Form(
                                    key: _form,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                              'Tiền thuê lẻ tính theo số ngày thực của tháng, gồm ngày trả. Không thu lại tiền thuê tháng đã có hóa đơn.'),
                                          const SizedBox(height: 20),
                                          _field('moveOutDate',
                                              'Ngày trả phòng (YYYY-MM-DD)',
                                              numeric: false),
                                          const SizedBox(height: 20),
                                          Text('Điện, nước cuối kỳ',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          const Text(
                                              'Bỏ trống nếu không chốt phát sinh. Chỉ số nền lấy từ lần ghi gần nhất hoặc biên bản nhận phòng.'),
                                          const SizedBox(height: 12),
                                          LayoutBuilder(
                                              builder: (context, constraints) =>
                                                  Wrap(
                                                      spacing: 12,
                                                      runSpacing: 12,
                                                      children: [
                                                        for (final entry in {
                                                          'finalElectricity':
                                                              'Chỉ số điện cuối',
                                                          'electricityUnitPrice':
                                                              'Đơn giá điện (VND)',
                                                          'finalWater':
                                                              'Chỉ số nước cuối',
                                                          'waterUnitPrice':
                                                              'Đơn giá nước (VND)',
                                                          'damage':
                                                              'Hư hỏng (VND)',
                                                          'cleaning':
                                                              'Vệ sinh (VND)',
                                                          'other':
                                                              'Chi phí khác (VND)'
                                                        }.entries)
                                                          SizedBox(
                                                              width: constraints
                                                                          .maxWidth >
                                                                      600
                                                                  ? (constraints
                                                                              .maxWidth -
                                                                          12) /
                                                                      2
                                                                  : constraints
                                                                      .maxWidth,
                                                              child: _field(
                                                                  entry.key,
                                                                  entry.value)),
                                                      ])),
                                          const SizedBox(height: 16),
                                          _field('note',
                                              'Lý do, tình trạng phòng và giải thích chi phí',
                                              numeric: false),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                              onPressed:
                                                  _busy ? null : _prepare,
                                              child: const Text(
                                                  'Xem trước quyết toán')),
                                          if (_preview != null) ...[
                                            const SizedBox(height: 20),
                                            _summary(_preview!,
                                                confirmed: false)
                                          ],
                                        ])),
                            ]),
                      ))),
    );
  }
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog();
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController(), _reason = TextEditingController();
  @override
  void dispose() {
    _reference.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Ghi nhận đã hoàn cọc'),
          content: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Thao tác này chỉ ghi sổ; không thực hiện chuyển tiền. Nhập mã chuyển khoản hoặc biên nhận đã trao tiền.'),
                    TextFormField(
                        controller: _reference,
                        maxLength: 120,
                        decoration: const InputDecoration(
                            labelText: 'Mã chuyển khoản / biên nhận'),
                        validator: (value) => (value?.trim().length ?? 0) < 3
                            ? 'Nhập mã tham chiếu.'
                            : null),
                    TextFormField(
                        controller: _reason,
                        maxLength: 1000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Ghi chú xác nhận'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Nhập ít nhất 10 ký tự.'
                            : null),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, {
                      'reference': _reference.text.trim(),
                      'reason': _reason.text.trim()
                    });
                  }
                },
                child: const Text('Ghi nhận'))
          ]);
}

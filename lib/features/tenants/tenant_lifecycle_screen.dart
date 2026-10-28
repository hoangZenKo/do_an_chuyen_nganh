import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/format.dart';
import '../../core/utils/request_key.dart';
import '../../data/tenants/tenant_lifecycle_api.dart';
import '../../models/lease.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'lease_settlement_screen.dart';
import 'tenant_providers.dart';
import '../tenant_portal/tenant_portal_providers.dart';

final tenantLifecycleApiProvider = Provider<TenantLifecycleApi>((ref) =>
    TenantLifecycleApi(ref.watch(sessionDioProvider).client,
        ownerId: ref.watch(sessionIdentityProvider)));

String lifecycleTypeLabel(String type) => switch (type) {
      'RENEWAL' => 'Gia hạn',
      'TRANSFER_ROOM' => 'Chuyển phòng',
      'CHECKOUT' => 'Trả phòng',
      _ => type,
    };
String lifecycleStatusLabel(String status) => switch (status) {
      'PENDING' => 'Chờ duyệt',
      'APPROVED' => 'Đã duyệt yêu cầu',
      'REJECTED' => 'Đã từ chối',
      'CANCELLED' => 'Đã hủy',
      _ => status,
    };

class TenantLifecycleScreen extends ConsumerStatefulWidget {
  const TenantLifecycleScreen(
      {super.key,
      required this.leaseId,
      this.tenantLease,
      this.managementLease});
  final String leaseId;
  final TenantPortalLease? tenantLease;
  final Lease? managementLease;
  @override
  ConsumerState<TenantLifecycleScreen> createState() => _LifecycleState();
}

class _LifecycleState extends ConsumerState<TenantLifecycleScreen> {
  late final String? _owner;
  late final TenantLifecycleApi _api;
  List<Map<String, dynamic>> _requests = [], _occupants = [];
  Map<String, dynamic>? _settlement;
  String? _cursor, _status, _error;
  bool _loading = true, _busy = false, _uncertain = false;
  int _generation = 0;
  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  bool get _tenant =>
      ref.read(sessionControllerProvider).session?.user.role == 'tenant';
  bool get _manage =>
      sessionHasPermission(
          ref.read(sessionControllerProvider).session, 'lease.manage') &&
      !_tenant;
  bool get _landlord =>
      ref.read(sessionControllerProvider).session?.user.role == 'landlord';

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _api = ref.read(tenantLifecycleApiProvider);
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!_active) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.requests(
          tenant: _tenant,
          leaseId: widget.leaseId,
          status: _status,
          cursor: more ? _cursor : null);
      final occupants = await _api.occupants(widget.leaseId, tenant: _tenant);
      final settlement = _tenant ? await _api.settlement(widget.leaseId) : null;
      if (!_active || generation != _generation) return;
      setState(() {
        _requests = more ? [..._requests, ...page.rows] : page.rows;
        _cursor = page.nextCursor;
        _occupants = occupants;
        _settlement = settlement;
        _uncertain = false;
      });
    } catch (error) {
      if (_active && generation == _generation) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (_active && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _message(Object error) => error is ApiFailure &&
          error.statusCode == 403
      ? 'Bạn không có quyền thao tác hợp đồng này.'
      : error is ApiFailure && error.statusCode == 409
          ? 'Dữ liệu đã thay đổi hoặc yêu cầu đã được xử lý. Tải lại để kiểm tra trước khi thao tác tiếp.'
          : error is ApiFailure
              ? error.message
              : 'Không thể tải dữ liệu. Kiểm tra kết nối và thử lại.';

  Future<void> _mutate(Future<void> Function() action) async {
    if (!_active || _busy || _uncertain) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (_active) await _load();
    } catch (error) {
      if (_active) {
        setState(() {
          _error = _message(error);
          _uncertain = error is! ApiFailure ||
              error.statusCode == null ||
              error.statusCode! >= 500 ||
              error.statusCode == 409;
        });
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> request, String status) async {
    final reason = await _textDialog(
        context,
        status == 'APPROVED' ? 'Duyệt yêu cầu' : 'Từ chối yêu cầu',
        'Lý do xử lý',
        help:
            'Duyệt chỉ ghi nhận đồng ý. Hợp đồng, cọc và công nợ chỉ đổi khi thực hiện bước nghiệp vụ tương ứng.');
    if (reason != null && _active) {
      await _mutate(() => _api.review(request, status, reason));
    }
  }

  Future<void> _create() async {
    final lease = widget.tenantLease;
    if (lease == null || !lease.isActive || !_active) return;
    final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LifecycleRequestForm(lease: lease)));
    if (_active && result == true) await _load();
  }

  Future<void> _addOccupant() async {
    final name = await _textDialog(context, 'Thêm người ở cùng', 'Họ và tên',
        help:
            'Tổng số người gồm người đứng hợp đồng không được vượt sức chứa phòng.');
    if (name != null && _active) {
      await _mutate(() => _api.addOccupant(widget.leaseId, {'fullName': name}));
    }
  }

  Future<void> _execute(Map<String, dynamic> request) async {
    int? rent;
    if (request['type'] == 'TRANSFER_ROOM') {
      final value = await _textDialog(
          context, 'Thực hiện chuyển phòng', 'Giá thuê phòng mới (VND)',
          help:
              'Phải quyết toán phòng cũ trước. Hợp đồng mới không tự thu/chuyển cọc; dùng sổ cọc hiện có để ghi nhận giao dịch thực tế.');
      if (value == null || !_active) return;
      rent = int.tryParse(value);
      if (rent == null || rent < 0 || rent > 2147483647) {
        setState(() => _error = 'Giá thuê phải là số nguyên VND hợp lệ.');
        return;
      }
    } else {
      if (!await _confirm(context,
              'Thực hiện ${lifecycleTypeLabel(request['type'] as String).toLowerCase()} đã duyệt?') ||
          !_active) {
        return;
      }
    }
    await _mutate(
        () => _api.execute(request, newRequestKey(), monthlyRent: rent));
    if (_active) {
      ref.invalidate(
          tenantLeasesProvider(widget.managementLease?.tenantId ?? ''));
      ref.invalidate(tenantPortalLeasesProvider);
      ref.invalidate(tenantPortalDashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final enabled = !_busy && !_loading && !_uncertain;
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu & người ở cùng')),
      body: !_active
          ? const Center(
              child: Text(
                  'Phiên tài khoản đã thay đổi. Vui lòng mở lại hợp đồng.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    if (_uncertain)
                      const Text(
                          'Chưa xác định kết quả thao tác. Không tự gửi lại; tải trạng thái mới trước.'),
                    TextButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại trạng thái')),
                  ],
                  if (_tenant && widget.tenantLease?.isActive == true)
                    FilledButton.icon(
                        onPressed: enabled ? _create : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Gửi yêu cầu mới')),
                  DropdownButtonFormField<String>(
                      value: _status ?? 'ALL',
                      decoration: const InputDecoration(
                          labelText: 'Trạng thái yêu cầu'),
                      items: [
                        const DropdownMenuItem(
                            value: 'ALL', child: Text('Tất cả')),
                        for (final status in [
                          'PENDING',
                          'APPROVED',
                          'REJECTED',
                          'CANCELLED'
                        ])
                          DropdownMenuItem(
                              value: status,
                              child: Text(lifecycleStatusLabel(status)))
                      ],
                      onChanged: _loading || _busy
                          ? null
                          : (value) {
                              setState(() =>
                                  _status = value == 'ALL' ? null : value);
                              _load();
                            }),
                  const SizedBox(height: 16),
                  if (!_loading && _requests.isEmpty)
                    const Text('Chưa có yêu cầu phù hợp.'),
                  for (final request in _requests) ...[
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${lifecycleTypeLabel(request['type'] as String)} · ${lifecycleStatusLabel(request['status'] as String)}'),
                        subtitle: Text([
                          if (request['requestedStart'] != null)
                            'Ngày dự kiến: ${formatDate(DateTime.tryParse(request['requestedStart'] as String))}',
                          if (request['requestedEnd'] != null)
                            'Đến: ${formatDate(DateTime.tryParse(request['requestedEnd'] as String))}',
                          if (request['requestedRoom'] != null)
                            'Phòng đến: ${request['requestedRoom']['name']}',
                          if (request['note'] != null) '${request['note']}',
                          if (request['decisionNote'] != null)
                            'Lý do xử lý: ${request['decisionNote']}',
                          if (request['reviewedAt'] != null)
                            'Xử lý: ${formatDate(DateTime.tryParse(request['reviewedAt'] as String))}',
                        ].join('\n'))),
                    if (request['status'] == 'PENDING')
                      Wrap(spacing: 8, children: [
                        if (_tenant)
                          OutlinedButton(
                              onPressed: enabled
                                  ? () async {
                                      final yes = await _confirm(
                                          context, 'Hủy yêu cầu này?');
                                      if (yes && _active) {
                                        await _mutate(
                                            () => _api.cancel(request));
                                      }
                                    }
                                  : null,
                              child: const Text('Hủy yêu cầu')),
                        if (_manage) ...[
                          FilledButton(
                              onPressed: enabled
                                  ? () => _review(request, 'APPROVED')
                                  : null,
                              child: const Text('Duyệt')),
                          OutlinedButton(
                              onPressed: enabled
                                  ? () => _review(request, 'REJECTED')
                                  : null,
                              child: const Text('Từ chối')),
                        ],
                      ]),
                    if (request['execution'] != null)
                      Text(
                          'Đã thực hiện · ${formatDate(DateTime.tryParse(request['execution']['createdAt'] as String))}')
                    else if (request['status'] == 'APPROVED') ...[
                      const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                              'Yêu cầu đã được đồng ý, chưa thực hiện. Trả/chuyển phòng phải xác nhận quyết toán trước.')),
                      if (_manage)
                        OutlinedButton(
                            onPressed: enabled ? () => _execute(request) : null,
                            child: const Text('Thực hiện yêu cầu đã duyệt')),
                    ],
                    const Divider(),
                  ],
                  if (_cursor != null)
                    TextButton(
                        onPressed: enabled ? () => _load(more: true) : null,
                        child: const Text('Xem thêm yêu cầu')),
                  const SizedBox(height: 20),
                  Text('Người ở cùng',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Text(
                      'Danh sách này không bao gồm người đứng hợp đồng.'),
                  if (_occupants.isEmpty && !_loading)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa ghi nhận người ở cùng.')),
                  for (final occupant in _occupants)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(occupant['fullName'] as String),
                        subtitle:
                            Text(occupant['relationship'] as String? ?? ''),
                        trailing: _manage &&
                                widget.managementLease?.status ==
                                    LeaseStatus.active
                            ? IconButton(
                                tooltip: 'Xóa người ở cùng',
                                onPressed: enabled
                                    ? () async {
                                        if (await _confirm(context,
                                                'Xóa ${occupant['fullName']} khỏi danh sách?') &&
                                            _active) {
                                          await _mutate(() =>
                                              _api.removeOccupant(
                                                  widget.leaseId,
                                                  occupant['id'] as String));
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.person_remove_outlined))
                            : null),
                  if (_manage &&
                      widget.managementLease?.status == LeaseStatus.active)
                    OutlinedButton.icon(
                        onPressed: enabled ? _addOccupant : null,
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Thêm người ở cùng')),
                  if (_tenant) ...[
                    const SizedBox(height: 20),
                    Text('Quyết toán',
                        style: Theme.of(context).textTheme.titleLarge),
                    if (_settlement == null)
                      const Text(
                          'Chưa có quyết toán được xác nhận. Gửi yêu cầu trả phòng không tự kết thúc hợp đồng hoặc hoàn cọc.')
                    else ...[
                      for (final entry in {
                        'totalCharges': 'Chi phí quyết toán',
                        'depositApplied': 'Cấn trừ cọc',
                        'balanceDue': 'Phải thu quyết toán',
                        'outstandingInvoiceAmount':
                            'Công nợ hóa đơn cũ (tách riêng)',
                        'refundAmount': 'Tiền phải hoàn'
                      }.entries)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.value),
                            trailing: Text(formatCurrencyVnd(
                                _settlement![entry.key] as int))),
                      Text(_settlement!['refundStatus'] == 'PAID'
                          ? 'Chủ trọ đã xác nhận hoàn tiền · ${_settlement!['refundReference'] ?? ''}'
                          : _settlement!['refundStatus'] == 'PENDING'
                              ? 'Chưa xác nhận đã hoàn tiền'
                              : 'Không có khoản hoàn'),
                    ],
                  ],
                  if (_landlord && widget.managementLease != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        onPressed: enabled
                            ? () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => LeaseSettlementScreen(
                                            lease: widget.managementLease!)));
                                if (_active) await _load();
                              }
                            : null,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Mở quyết toán hiện có')),
                  ],
                  const SizedBox(height: 32),
                ],
              )),
    );
  }
}

class LifecycleRequestForm extends ConsumerStatefulWidget {
  const LifecycleRequestForm({super.key, required this.lease});
  final TenantPortalLease lease;
  @override
  ConsumerState<LifecycleRequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<LifecycleRequestForm> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController(),
      _note = TextEditingController(),
      _search = TextEditingController();
  late final String? _owner;
  late final TenantLifecycleApi _api;
  String _type = 'RENEWAL';
  String? _roomId, _cursor, _error;
  List<Map<String, dynamic>> _rooms = [];
  bool _busy = false, _loadingRooms = false, _uncertain = false;
  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _api = ref.read(tenantLifecycleApiProvider);
  }

  @override
  void dispose() {
    _date.dispose();
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRooms({bool more = false}) async {
    if (_loadingRooms || !_active) return;
    setState(() {
      _loadingRooms = true;
      _error = null;
    });
    try {
      final page = await _api.transferRooms(widget.lease.id,
          search: _search.text, cursor: more ? _cursor : null);
      if (_active) {
        setState(() {
          _rooms = more ? [..._rooms, ...page.rows] : page.rows;
          _cursor = page.nextCursor;
          _roomId = null;
        });
      }
    } catch (error) {
      if (_active) setState(() => _error = '$error');
    } finally {
      if (_active) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _submit() async {
    if (!_active || _busy || _uncertain || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.create({
        'leaseId': widget.lease.id,
        'type': _type,
        'note': _note.text.trim(),
        if (_type == 'RENEWAL')
          'requestedEnd': _date.text.trim()
        else
          'requestedStart': _date.text.trim(),
        if (_type == 'TRANSFER_ROOM') 'requestedRoomId': _roomId
      });
      if (mounted && _active) Navigator.of(context).pop(true);
    } catch (error) {
      if (_active) {
        setState(() {
          _uncertain = error is! ApiFailure ||
              error.statusCode == null ||
              error.statusCode! >= 500 ||
              error.statusCode == 409;
          _error = _uncertain
              ? 'Chưa xác định kết quả hoặc đã có yêu cầu. Quay lại và tải danh sách trước khi gửi tiếp.'
              : '$error';
        });
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Gửi yêu cầu hợp đồng')),
        body: !_active
            ? const Center(child: Text('Phiên tài khoản đã thay đổi.'))
            : Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text(
                      'Phòng ${widget.lease.roomName} · ${widget.lease.propertyName}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      value: _type,
                      decoration:
                          const InputDecoration(labelText: 'Loại yêu cầu'),
                      items: [
                        for (final type in [
                          'RENEWAL',
                          'TRANSFER_ROOM',
                          'CHECKOUT'
                        ])
                          DropdownMenuItem(
                              value: type,
                              child: Text(lifecycleTypeLabel(type)))
                      ],
                      onChanged: _busy || _uncertain
                          ? null
                          : (value) {
                              setState(() {
                                _type = value!;
                                _date.clear();
                                _roomId = null;
                              });
                              if (value == 'TRANSFER_ROOM') _loadRooms();
                            }),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _date,
                      enabled: !_busy && !_uncertain,
                      decoration: InputDecoration(
                          labelText: _type == 'RENEWAL'
                              ? 'Gia hạn đến ngày (YYYY-MM-DD)'
                              : 'Ngày dự kiến (YYYY-MM-DD)'),
                      keyboardType: TextInputType.datetime,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        final date = DateTime.tryParse(text);
                        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
                            date == null ||
                            date.toIso8601String().substring(0, 10) != text) {
                          return 'Nhập ngày hợp lệ theo YYYY-MM-DD.';
                        }
                        if (_type == 'RENEWAL' &&
                            !date.isAfter(
                                widget.lease.endDate ?? DateTime.now())) {
                          return 'Ngày mới phải sau ngày hết hạn hiện tại.';
                        }
                        return null;
                      }),
                  if (_type == 'TRANSFER_ROOM') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _search,
                        decoration: InputDecoration(
                            labelText: 'Tìm phòng trống',
                            suffixIcon: IconButton(
                                tooltip: 'Tìm phòng',
                                onPressed:
                                    _busy || _loadingRooms ? null : _loadRooms,
                                icon: const Icon(Icons.search)))),
                    if (_loadingRooms) const LinearProgressIndicator(),
                    DropdownButtonFormField<String>(
                        key: ValueKey('${_rooms.length}:$_roomId'),
                        value: _roomId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Phòng muốn chuyển đến'),
                        items: [
                          for (final room in _rooms)
                            DropdownMenuItem(
                                value: room['id'] as String,
                                child: Text(
                                    '${room['name']} · ${room['property']['name']}',
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: _busy || _loadingRooms || _uncertain
                            ? null
                            : (value) => setState(() => _roomId = value),
                        validator: (value) =>
                            _type == 'TRANSFER_ROOM' && value == null
                                ? 'Chọn phòng muốn chuyển đến.'
                                : null),
                    if (_rooms.isEmpty && !_loadingRooms)
                      const Text(
                          'Không có phòng trống phù hợp. Liên hệ chủ trọ hoặc tìm lại.'),
                    if (_cursor != null)
                      TextButton(
                          onPressed: _loadingRooms || _busy
                              ? null
                              : () => _loadRooms(more: true),
                          child: const Text('Xem thêm phòng')),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _note,
                      enabled: !_busy && !_uncertain,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration:
                          const InputDecoration(labelText: 'Lý do / ghi chú'),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Vui lòng nhập lý do.'),
                  const Text(
                      'Yêu cầu chờ chủ trọ/nhân viên duyệt; không tự thay đổi hợp đồng, tiền cọc hoặc công nợ.'),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed:
                          _busy || _uncertain || _loadingRooms ? null : _submit,
                      child: Text(_busy ? 'Đang gửi...' : 'Gửi yêu cầu')),
                ])));
  }
}

Future<bool> _confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(title: Text(title), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Không')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Xác nhận')),
            ])) ??
    false;

Future<String?> _textDialog(BuildContext context, String title, String label,
    {required String help}) async {
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                  width: 420,
                  child: Form(
                      key: form,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(help),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: input,
                                autofocus: true,
                                maxLength: 1000,
                                decoration: InputDecoration(labelText: label),
                                validator: (value) =>
                                    value?.trim().isNotEmpty == true
                                        ? null
                                        : 'Không được để trống.'),
                          ])))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy')),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, input.text.trim());
                      }
                    },
                    child: const Text('Xác nhận'))
              ]));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  input.dispose();
  return result;
}

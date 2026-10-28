import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/request_key.dart';
import '../../models/billing_tariff.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../rooms/room_providers.dart';
import 'billing_providers.dart';

class BillingTariffsScreen extends ConsumerWidget {
  const BillingTariffsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(sessionIdentityProvider);
    final session = ref.watch(sessionControllerProvider).session;
    if (!sessionHasPermission(session, 'billing.view')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Biểu phí')),
        body: const _EmptyState(
          icon: Icons.lock_outline,
          title: 'Không có quyền xem biểu phí',
          message: 'Cần quyền xem hóa đơn để mở chức năng này.',
        ),
      );
    }
    return _BillingTariffsWorkspace(key: ValueKey(identity));
  }
}

class _BillingTariffsWorkspace extends ConsumerStatefulWidget {
  const _BillingTariffsWorkspace({super.key});

  @override
  ConsumerState<_BillingTariffsWorkspace> createState() =>
      _BillingTariffsScreenState();
}

class _BillingTariffsScreenState
    extends ConsumerState<_BillingTariffsWorkspace> {
  final _formKey = GlobalKey<FormState>();
  final _serviceKey = TextEditingController();
  final _name = TextEditingController();
  final _unit = TextEditingController(text: 'tháng');
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final List<_TierDraft> _tiers = [];
  String _kind = 'SERVICE';
  String? _roomId;
  DateTime _effectiveMonth = _businessMonth();
  String? _selectedImpactId;
  bool _isActive = true;
  bool _saving = false;
  bool _blocked = false;
  bool _checking = false;
  bool _showProposal = false;
  String? _error;
  final Map<String, String> _proposalKeys = {};
  late final String? _identity = ref.read(sessionIdentityProvider);

  bool get _sameAccount =>
      mounted && ref.read(sessionIdentityProvider) == _identity;

  @override
  void dispose() {
    _serviceKey.dispose();
    _name.dispose();
    _unit.dispose();
    _amount.dispose();
    _reason.dispose();
    for (final tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final propertiesAsync = ref.watch(propertiesProvider);
    final propertyId = ref.watch(selectedPropertyProvider);
    final canPropose = sessionHasPermission(session, 'billing.create');
    final canApprove = session?.user.role == 'landlord' &&
        sessionHasPermission(session, 'billing.tariff_approve');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biểu phí'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: propertyId == null || _saving || _checking
                ? null
                : () => _reload(propertyId),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: propertiesAsync.when(
        skipError: propertiesAsync.hasValue,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiFailure && error.statusCode == 403
              ? 'Cần quyền xem khu trọ (property.view) để chọn khu trọ. Vui lòng liên hệ landlord để kiểm tra quyền.'
              : '$error',
          onRetry: () => ref.invalidate(propertiesProvider),
        ),
        data: (properties) {
          if (properties.isEmpty || propertyId == null) {
            return const _EmptyState(
              icon: Icons.home_work_outlined,
              title: 'Chưa có khu trọ',
              message: 'Tạo khu trọ trước khi thiết lập biểu phí.',
            );
          }
          final property = properties.firstWhere(
            (item) => item.id == propertyId,
            orElse: () => properties.first,
          );
          final tariffsAsync = ref.watch(billingTariffsProvider(property.id));
          return RefreshIndicator(
            onRefresh: () => _reload(property.id),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (propertiesAsync.hasError)
                    const _InlineError(
                        message:
                            'Chưa tải được danh sách khu trọ mới. Đang giữ dữ liệu trước đó.'),
                  AbsorbPointer(
                      absorbing: _saving || _checking,
                      child: _PropertyPicker(
                        properties: properties,
                        selectedId: property.id,
                        onChanged: (id) {
                          ref.read(selectedPropertyProvider.notifier).state =
                              id;
                          setState(() {
                            _roomId = null;
                            _selectedImpactId = null;
                            _showProposal = false;
                            _blocked = false;
                            _error = null;
                          });
                        },
                      )),
                  const SizedBox(height: 20),
                  _PageIntro(property: property),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    _InlineError(message: _error!),
                    if (_blocked)
                      OutlinedButton.icon(
                        onPressed:
                            _checking ? null : () => _reload(property.id),
                        icon: const Icon(Icons.refresh),
                        label: Text(_checking
                            ? 'Đang đối chiếu…'
                            : 'Tải lại để đối chiếu'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (canPropose)
                    OutlinedButton.icon(
                      onPressed: _saving || _blocked
                          ? null
                          : () =>
                              setState(() => _showProposal = !_showProposal),
                      icon: Icon(_showProposal ? Icons.expand_less : Icons.add),
                      label: Text(_showProposal
                          ? 'Thu gọn đề xuất'
                          : 'Tạo đề xuất biểu phí'),
                    ),
                  if (canPropose && _showProposal)
                    AbsorbPointer(
                        absorbing: _saving || _blocked || _checking,
                        child: _ProposalForm(
                          formKey: _formKey,
                          kind: _kind,
                          serviceKey: _serviceKey,
                          name: _name,
                          unit: _unit,
                          amount: _amount,
                          reason: _reason,
                          isActive: _isActive,
                          effectiveMonth: _effectiveMonth,
                          roomId: _roomId,
                          tiers: _tiers,
                          roomsAsync: sessionHasPermission(session, 'room.view')
                              ? ref.watch(roomsProvider(property.id))
                              : const AsyncValue.data([]),
                          onRetryRooms: () =>
                              ref.invalidate(roomsProvider(property.id)),
                          saving: _saving,
                          error: null,
                          onKindChanged: (value) => setState(() {
                            _kind = value;
                            if (value == 'SERVICE') _clearTiers();
                            if (value != 'SERVICE') {
                              _name.text =
                                  value == 'ELECTRICITY' ? 'Điện' : 'Nước';
                              _unit.text =
                                  value == 'ELECTRICITY' ? 'kWh' : 'm³';
                            }
                          }),
                          onRoomChanged: (value) =>
                              setState(() => _roomId = value),
                          onActiveChanged: (value) =>
                              setState(() => _isActive = value),
                          onMonthChanged: _pickEffectiveMonth,
                          onAddTier: _addTier,
                          onRemoveTier: _removeTier,
                          onSubmit: () => _submitProposal(property.id),
                        )),
                  if (canPropose) const SizedBox(height: 24),
                  tariffsAsync.when(
                    skipError: tariffsAsync.hasValue,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _ErrorState(
                      message: '$error',
                      onRetry: () =>
                          ref.invalidate(billingTariffsProvider(property.id)),
                    ),
                    data: (tariffs) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (tariffsAsync.hasError)
                            const _InlineError(
                                message:
                                    'Tải lại thất bại. Đang hiển thị dữ liệu đã tải; tải lại thành công trước khi duyệt.'),
                          if (tariffsAsync.isLoading)
                            const LinearProgressIndicator(),
                          _TariffHistory(
                            key: ValueKey(property.id),
                            tariffs: tariffs,
                            selectedId: _selectedImpactId,
                            onSelect: (id) =>
                                setState(() => _selectedImpactId = id),
                          )
                        ]),
                  ),
                  if (_selectedImpactId != null) ...[
                    const SizedBox(height: 18),
                    _ImpactPanel(
                      id: _selectedImpactId!,
                      canApprove: canApprove,
                      busy: _saving ||
                          _blocked ||
                          _checking ||
                          tariffsAsync.hasError ||
                          tariffsAsync.isLoading,
                      onReview: (decision) =>
                          _reviewTariff(_selectedImpactId!, decision),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitProposal(String propertyId) async {
    if (!_sameAccount ||
        _saving ||
        _blocked ||
        _checking ||
        !sessionHasPermission(
            ref.read(sessionControllerProvider).session, 'billing.create') ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null) return;
    if (_kind != 'SERVICE' && !_validTiers()) {
      setState(() =>
          _error = 'Các bậc phải tăng dần và bậc cuối để trống giới hạn.');
      return;
    }
    final tiers = _tiers.map((tier) => tier.toJson()).toList(growable: false);
    final serviceKey =
        _kind == 'SERVICE' ? _serviceKey.text.trim() : _kind.toLowerCase();
    final fingerprint = jsonEncode({
      'propertyId': propertyId,
      'roomId': _roomId,
      'kind': _kind,
      'serviceKey': serviceKey,
      'name': _name.text.trim(),
      'unit': _unit.text.trim(),
      'amount': amount,
      'isActive': _isActive,
      'effectiveFrom': _effectiveMonth.toIso8601String(),
      'tiers': tiers,
      'reason': _reason.text.trim(),
    });
    final requestKey = _proposalKeys.putIfAbsent(fingerprint, newRequestKey);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(billingRepositoryProvider).proposeTariff(
            requestKey: requestKey,
            propertyId: propertyId,
            roomId: _roomId,
            kind: _kind,
            serviceKey: serviceKey,
            name: _name.text,
            unit: _unit.text,
            amount: amount,
            isActive: _isActive,
            effectiveFrom: _effectiveMonth.toIso8601String(),
            tiers: tiers,
            reason: _reason.text,
          );
      if (mounted && _sameAccount) {
        ref.invalidate(billingTariffsProvider(propertyId));
        setState(() {
          _saving = false;
          _selectedImpactId = result.id;
          _proposalKeys.remove(fingerprint);
          _showProposal = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đề xuất biểu phí để duyệt.')),
        );
      }
    } catch (error) {
      if (_sameAccount) {
        setState(() {
          _saving = false;
          _blocked = _needsReload(error);
          _error = _message(error);
          if (!_blocked) _proposalKeys.remove(fingerprint);
        });
      }
    }
  }

  Future<void> _reviewTariff(String id, String decision) async {
    if (!_sameAccount ||
        _saving ||
        _blocked ||
        _checking ||
        ref.read(sessionControllerProvider).session?.user.role != 'landlord') {
      return;
    }
    setState(() => _saving = true);
    final reason = await _askReason(
      context,
      title: decision == 'APPROVED' ? 'Duyệt biểu phí' : 'Từ chối biểu phí',
      action: decision == 'APPROVED' ? 'Duyệt' : 'Từ chối',
    );
    if (!_sameAccount) return;
    if (reason == null) {
      setState(() => _saving = false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(billingRepositoryProvider).reviewTariff(
            id: id,
            requestKey: newRequestKey(),
            decision: decision,
            reason: reason,
          );
      if (mounted && _sameAccount) {
        final propertyId = ref.read(selectedPropertyProvider);
        if (propertyId != null) {
          ref.invalidate(billingTariffsProvider(propertyId));
        }
        ref.invalidate(billingTariffImpactProvider(id));
        setState(() {
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'APPROVED'
                ? 'Đã duyệt biểu phí.'
                : 'Đã từ chối biểu phí.'),
          ),
        );
      }
    } catch (error) {
      if (_sameAccount) {
        setState(() {
          _saving = false;
          _blocked = _needsReload(error);
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _pickEffectiveMonth() async {
    final minimum = _businessMonth();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _effectiveMonth.isBefore(minimum) ? minimum : _effectiveMonth,
      firstDate: minimum,
      lastDate: DateTime(minimum.year + 3, 12),
      helpText: 'Chọn tháng áp dụng',
    );
    if (picked != null && _sameAccount) {
      setState(() => _effectiveMonth = _monthStart(picked));
    }
  }

  void _addTier() {
    if (_tiers.length < 30) setState(() => _tiers.add(_TierDraft()));
  }

  void _removeTier(int index) {
    final tier = _tiers.removeAt(index);
    tier.dispose();
    setState(() {});
  }

  void _clearTiers() {
    for (final tier in _tiers) {
      tier.dispose();
    }
    _tiers.clear();
  }

  bool _validTiers() {
    if (_tiers.isEmpty) return true;
    var previous = 0;
    for (var i = 0; i < _tiers.length; i++) {
      final tier = _tiers[i];
      final price = int.tryParse(tier.unitPrice.text.trim());
      if (price == null || price < 0 || price > 2147483647) return false;
      final limit = tier.upTo.text.trim().isEmpty
          ? null
          : int.tryParse(tier.upTo.text.trim());
      if (i == _tiers.length - 1 && limit != null) return false;
      if (i != _tiers.length - 1 && limit == null) return false;
      if (limit != null && limit > 2147483647) return false;
      if (limit != null && limit <= previous) return false;
      if (limit != null) previous = limit;
    }
    return true;
  }

  static DateTime _monthStart(DateTime date) =>
      DateTime.utc(date.year, date.month, 1);

  static DateTime _businessMonth() => _monthStart(
        DateTime.now().toUtc().add(const Duration(hours: 7)),
      );

  Future<void> _reload(String propertyId) async {
    if (_saving || _checking || !_sameAccount) return;
    setState(() => _checking = true);
    try {
      ref.invalidate(billingTariffsProvider(propertyId));
      await ref.read(billingTariffsProvider(propertyId).future);
      if (!_sameAccount) return;
      final impactId = _selectedImpactId;
      if (impactId != null) {
        ref.invalidate(billingTariffImpactProvider(impactId));
        await ref.read(billingTariffImpactProvider(impactId).future);
      }
      if (!_sameAccount) return;
      setState(() {
        _checking = false;
        _blocked = false;
        _error = null;
      });
    } catch (error) {
      if (_sameAccount) {
        setState(() {
          _checking = false;
          _error =
              'Không tải được dữ liệu mới. Dữ liệu trước đó vẫn được giữ lại.';
        });
      }
    }
  }

  static bool _needsReload(Object error) =>
      error is! ApiFailure ||
      error.statusCode == null ||
      error.statusCode == 409 ||
      (error.statusCode ?? 0) >= 500;

  static String _message(Object error) {
    if (error is ApiFailure) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Phiên đăng nhập hoặc quyền truy cập đã thay đổi. Vui lòng kiểm tra tài khoản.';
      }
      if (error.statusCode == 409) {
        return 'Đề xuất đã thay đổi hoặc kỳ áp dụng không còn hợp lệ. Tải lại để đối chiếu trước khi thao tác tiếp.';
      }
      if (error.statusCode != null && error.statusCode! < 500) {
        return error.message;
      }
    }
    return 'Chưa xác định kết quả gửi. Không tự gửi lại; tải lại để đối chiếu trước khi tiếp tục.';
  }
}

class _TierDraft {
  final upTo = TextEditingController();
  final unitPrice = TextEditingController();

  Map<String, dynamic> toJson() => {
        'upTo':
            upTo.text.trim().isEmpty ? null : int.tryParse(upTo.text.trim()),
        'unitPrice': int.tryParse(unitPrice.text.trim()) ?? 0,
      };

  void dispose() {
    upTo.dispose();
    unitPrice.dispose();
  }
}

class _PropertyPicker extends StatelessWidget {
  const _PropertyPicker({
    required this.properties,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Property> properties;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Khu trọ đang quản lý',
        prefixIcon: Icon(Icons.home_work_outlined),
      ),
      items: properties
          .map((property) => DropdownMenuItem(
                value: property.id,
                child: Text(property.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Biểu phí & tiện ích',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Đề xuất theo tháng áp dụng. Biểu phí khu trọ dùng làm mặc định; biểu phí phòng sẽ ghi đè khi lập hóa đơn.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
            property.address.isEmpty
                ? 'Dữ liệu theo khu trọ'
                : property.address,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ProposalForm extends StatelessWidget {
  const _ProposalForm({
    required this.formKey,
    required this.kind,
    required this.serviceKey,
    required this.name,
    required this.unit,
    required this.amount,
    required this.reason,
    required this.isActive,
    required this.effectiveMonth,
    required this.roomId,
    required this.tiers,
    required this.roomsAsync,
    required this.onRetryRooms,
    required this.saving,
    required this.error,
    required this.onKindChanged,
    required this.onRoomChanged,
    required this.onActiveChanged,
    required this.onMonthChanged,
    required this.onAddTier,
    required this.onRemoveTier,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final String kind;
  final TextEditingController serviceKey;
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController amount;
  final TextEditingController reason;
  final bool isActive;
  final DateTime effectiveMonth;
  final String? roomId;
  final List<_TierDraft> tiers;
  final AsyncValue<List<Room>> roomsAsync;
  final VoidCallback onRetryRooms;
  final bool saving;
  final String? error;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String?> onRoomChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onMonthChanged;
  final VoidCallback onAddTier;
  final ValueChanged<int> onRemoveTier;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tạo đề xuất mới',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Staff gửi đề xuất; landlord là người duyệt cuối.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Loại biểu phí',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'SERVICE', child: Text('Dịch vụ cố định')),
                  DropdownMenuItem(value: 'ELECTRICITY', child: Text('Điện')),
                  DropdownMenuItem(value: 'WATER', child: Text('Nước')),
                ],
                onChanged: (value) {
                  if (value != null) onKindChanged(value);
                },
              ),
              const SizedBox(height: 14),
              roomsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    const Text('Không tải được danh sách phòng.'),
                    TextButton(
                        onPressed: onRetryRooms, child: const Text('Thử lại')),
                  ],
                ),
                data: (rooms) => DropdownButtonFormField<String?>(
                  value: roomId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Phạm vi áp dụng',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Mặc định toàn khu trọ'),
                    ),
                    ...rooms.map((room) => DropdownMenuItem<String?>(
                          value: room.id,
                          child: Text(room.name),
                        )),
                  ],
                  onChanged: onRoomChanged,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final fields = [
                  if (kind == 'SERVICE')
                    _field(serviceKey, 'Mã biểu phí', 'internet',
                        required: true, maxLength: 100),
                  _field(name, 'Tên hiển thị', 'Internet',
                      required: true, maxLength: 200),
                  _field(unit, 'Đơn vị', kind == 'SERVICE' ? 'tháng' : 'kWh',
                      required: true, maxLength: 30),
                  _field(
                      amount,
                      kind == 'SERVICE' ? 'Đơn giá' : 'Đơn giá mặc định',
                      '100000',
                      numeric: true),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: fields
                      .map((field) => SizedBox(
                            width: wide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                            child: field,
                          ))
                      .toList(),
                );
              }),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onMonthChanged,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Áp dụng từ ${formatMonth(effectiveMonth)}'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Thu phí từ tháng áp dụng'),
                subtitle: const Text('Đề xuất vẫn cần landlord duyệt.'),
                value: isActive,
                onChanged: onActiveChanged,
              ),
              if (kind != 'SERVICE') ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    Text('Bậc sử dụng',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: tiers.length >= 30 ? null : onAddTier,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm bậc'),
                    ),
                  ],
                ),
                if (tiers.isEmpty)
                  Text('Để trống nếu tính một đơn giá theo mức dùng.',
                      style: Theme.of(context).textTheme.bodySmall),
                ...tiers.asMap().entries.map((entry) => _TierRow(
                      index: entry.key,
                      tier: entry.value,
                      onRemove: () => onRemoveTier(entry.key),
                    )),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: reason,
                maxLength: 500,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Lý do thay đổi',
                  hintText:
                      'Ví dụ: cập nhật đơn giá theo hợp đồng nhà cung cấp',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập lý do để lưu audit.'
                    : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: error!),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : onSubmit,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(saving ? 'Đang gửi…' : 'Gửi đề xuất'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = false,
    bool numeric = false,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters:
          numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        if ((required || numeric) && (value == null || value.trim().isEmpty)) {
          return 'Bắt buộc';
        }
        if (numeric) {
          final parsed = int.tryParse(value ?? '');
          if (parsed == null || parsed < 0 || parsed > 2147483647) {
            return 'Nhập số từ 0 đến 2.147.483.647.';
          }
        }
        return null;
      },
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow(
      {required this.index, required this.tier, required this.onRemove});

  final int index;
  final _TierDraft tier;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(
          child: TextFormField(
            controller: tier.upTo,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Bậc ${index + 1} đến',
              hintText: 'Để trống = không giới hạn',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: tier.unitPrice,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Đơn giá / đơn vị'),
          ),
        ),
        IconButton(
          tooltip: 'Xóa bậc',
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ]),
    );
  }
}

class _TariffHistory extends StatefulWidget {
  const _TariffHistory(
      {super.key,
      required this.tariffs,
      this.selectedId,
      required this.onSelect});

  final List<BillingTariffVersion> tariffs;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_TariffHistory> createState() => _TariffHistoryState();
}

class _TariffHistoryState extends State<_TariffHistory> {
  String _query = '';
  String _state = 'ALL';
  int _page = 0;
  static const _pageSize = 12;

  @override
  Widget build(BuildContext context) {
    if (widget.tariffs.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có phiên bản biểu phí',
        message: 'Đề xuất đầu tiên sẽ xuất hiện ở đây để theo dõi và duyệt.',
      );
    }
    final matches = widget.tariffs.where((tariff) {
      final searchable =
          '${tariff.name} ${tariff.serviceKey} ${tariff.roomId ?? ''}'
              .toLowerCase();
      return (_state == 'ALL' || tariff.state == _state) &&
          searchable.contains(_query.toLowerCase().trim());
    }).toList(growable: false);
    final pageCount = (matches.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
    final visible = matches.skip(page * _pageSize).take(_pageSize);
    final grouped = <String, List<BillingTariffVersion>>{};
    for (final tariff in visible) {
      grouped.putIfAbsent(tariff.serviceKey, () => []).add(tariff);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lịch sử biểu phí', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Chọn một đề xuất để xem phòng bị ảnh hưởng và quyết định.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
              labelText: 'Tìm tên, mã biểu phí hoặc mã phòng',
              prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() {
            _query = value;
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _state,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Trạng thái'),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('Tất cả trạng thái')),
            DropdownMenuItem(value: 'PROPOSED', child: Text('Chờ duyệt')),
            DropdownMenuItem(value: 'APPROVED', child: Text('Đã duyệt')),
            DropdownMenuItem(value: 'REJECTED', child: Text('Từ chối')),
          ],
          onChanged: (value) => setState(() {
            _state = value ?? 'ALL';
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty) const Text('Không có biểu phí khớp bộ lọc.'),
        ...grouped.entries.map((entry) => _TariffGroup(
              serviceKey: entry.key,
              tariffs: entry.value,
              selectedId: widget.selectedId,
              onSelect: widget.onSelect,
            )),
        if (pageCount > 1)
          Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                    tooltip: 'Trang trước',
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left)),
                Text(
                    'Trang ${page + 1}/$pageCount · ${matches.length} phiên bản',
                    textAlign: TextAlign.center),
                IconButton(
                    tooltip: 'Trang sau',
                    onPressed: page + 1 < pageCount
                        ? () => setState(() => _page = page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right)),
              ]),
      ],
    );
  }
}

class _TariffGroup extends StatelessWidget {
  const _TariffGroup(
      {required this.serviceKey,
      required this.tariffs,
      this.selectedId,
      required this.onSelect});

  final String serviceKey;
  final List<BillingTariffVersion> tariffs;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(serviceKey, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...tariffs.map((tariff) => Card(
              color: selectedId == tariff.id
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: InkWell(
                onTap: () => onSelect(tariff.id),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(tariff.isUtility
                            ? Icons.bolt_outlined
                            : Icons.room_service_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${tariff.name} · phiên bản ${tariff.version}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                              '${tariff.roomId == null ? 'Toàn khu trọ' : 'Ghi đè phòng'} · từ ${formatMonth(tariff.effectiveFrom)}'),
                          Text(tariff.tiers.isEmpty
                              ? '${formatCurrencyVnd(tariff.amount)} / ${tariff.unit}'
                              : 'Giá lũy tiến ${tariff.tiers.length} bậc / ${tariff.unit}'),
                          _StatusChip(state: tariff.state),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ]),
    );
  }
}

class _ImpactPanel extends ConsumerWidget {
  const _ImpactPanel(
      {required this.id,
      required this.canApprove,
      required this.busy,
      required this.onReview});

  final String id;
  final bool canApprove;
  final bool busy;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impact = ref.watch(billingTariffImpactProvider(id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: impact.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Không tải được ảnh hưởng'),
              const SizedBox(height: 8),
              Text('$error'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(billingTariffImpactProvider(id)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
          data: (data) => _ImpactContent(
            data: data,
            canApprove: canApprove,
            busy: busy,
            onReview: onReview,
          ),
        ),
      ),
    );
  }
}

class _ImpactContent extends StatelessWidget {
  const _ImpactContent(
      {required this.data,
      required this.canApprove,
      required this.busy,
      required this.onReview});

  final BillingTariffImpact data;
  final bool canApprove;
  final bool busy;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) {
    final proposed = data.proposed;
    final previous = data.previous;
    final delta = previous == null ||
            previous.tiers.isNotEmpty ||
            proposed.tiers.isNotEmpty
        ? null
        : proposed.amount - previous.amount;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Xem trước & phê duyệt',
                style: Theme.of(context).textTheme.titleLarge),
            _StatusChip(state: proposed.state),
          ]),
      const SizedBox(height: 12),
      Text(
          '${proposed.name} · áp dụng từ ${formatMonth(proposed.effectiveFrom)}'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Metric(label: 'Phòng ảnh hưởng', value: '${data.rooms.length}'),
        if (data.overriddenRooms.isNotEmpty)
          _Metric(
              label: 'Phòng có ghi đè',
              value: '${data.overriddenRooms.length}'),
        _Metric(label: 'Hóa đơn tương lai', value: '${data.issuedInvoices}'),
        _Metric(label: 'Kỳ đã khóa', value: '${data.lockedPeriods}'),
        if (delta != null)
          _Metric(
            label: 'Chênh lệch đơn giá',
            value: '${delta >= 0 ? '+' : ''}${formatCurrencyVnd(delta)}',
          ),
      ]),
      if (previous != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
                child: _CompareValue(
                    label: 'Bản được duyệt trước đó',
                    value:
                        '${formatCurrencyVnd(previous.amount)} / ${previous.unit}')),
            const Icon(Icons.arrow_forward_rounded, size: 18),
            Expanded(
                child: _CompareValue(
                    label: 'Đề xuất',
                    value:
                        '${formatCurrencyVnd(proposed.amount)} / ${proposed.unit}')),
          ]),
        ),
      ],
      if (previous == null)
        const Text(
            'Chưa có bản được duyệt cùng phạm vi trước đó. Hệ thống vẫn giữ thứ tự phòng > khu trọ > phí cũ.'),
      const SizedBox(height: 14),
      _VersionDetails(label: 'Phiên bản đang xem', tariff: proposed),
      if (previous != null)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Chi tiết phiên bản trước'),
          children: [
            _VersionDetails(label: 'Phiên bản trước', tariff: previous)
          ],
        ),
      const SizedBox(height: 14),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('Phòng ảnh hưởng tại tháng áp dụng (${data.rooms.length})'),
        subtitle: const Text(
            'Bản ghi đè được duyệt trong tương lai vẫn có thể đổi phạm vi ở các tháng sau.'),
        children: [
          if (data.rooms.isEmpty)
            const Text('Không có phòng áp dụng tại tháng này.'),
          ...data.rooms.map((room) =>
              ListTile(title: Text(room.name), subtitle: Text(room.id))),
          if (data.overriddenRooms.isNotEmpty) ...[
            const Text('Không áp dụng mặc định vì đã có biểu phí phòng:'),
            ...data.overriddenRooms
                .map((room) => ListTile(title: Text(room.name))),
          ],
        ],
      ),
      if (proposed.isProposed && data.blockingReasons.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: _InlineError(
            message: _blockingMessage(data.blockingReasons),
          ),
        ),
      if (canApprove && proposed.isProposed) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed:
                  data.canApprove && !busy ? () => onReview('APPROVED') : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Duyệt áp dụng'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => onReview('REJECTED'),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Từ chối'),
            ),
          ),
        ]),
        if (!data.canApprove)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                data.blockingReasons.isEmpty
                    ? 'Landlord có thể duyệt biểu phí sau khi kiểm tra ảnh hưởng.'
                    : 'Không thể duyệt: ${_blockingMessage(data.blockingReasons)}',
                style: const TextStyle(color: AppTheme.amber, fontSize: 12)),
          ),
      ],
    ]);
  }

  static String _blockingMessage(List<String> reasons) {
    final labels = <String, String>{
      'ISSUED_INVOICES': 'đã có hóa đơn phát hành',
      'LOCKED_PERIODS': 'đã có kỳ khóa',
      'ALREADY_REVIEWED': 'đã được xử lý',
      'BACKDATED': 'lùi về tháng đã qua',
      'EFFECTIVE_ORDER': 'không sau phiên bản đã duyệt gần nhất',
    };
    return reasons.map((reason) => labels[reason] ?? reason).join('; ');
  }
}

class _VersionDetails extends StatelessWidget {
  const _VersionDetails({required this.label, required this.tariff});

  final String label;
  final BillingTariffVersion tariff;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · v${tariff.version}',
              style: Theme.of(context).textTheme.titleMedium),
          Text(
              '${tariff.isActive ? 'Thu phí' : 'Ngừng biểu phí'} · từ ${formatMonth(tariff.effectiveFrom)} · ${tariff.roomId == null ? 'Toàn khu trọ' : 'Phòng ${tariff.roomId}'}'),
          if (tariff.tiers.isEmpty)
            Text('${formatCurrencyVnd(tariff.amount)} / ${tariff.unit}')
          else ...[
            const Text('Tính lũy tiến theo bậc sử dụng:'),
            ...tariff.tiers.asMap().entries.map((entry) {
              final lower =
                  entry.key == 0 ? 0 : tariff.tiers[entry.key - 1].upTo;
              final upper = entry.value.upTo;
              return Text(
                  'Bậc ${entry.key + 1}: trên $lower${upper == null ? ' (không giới hạn)' : ' đến $upper'} ${tariff.unit} · ${formatCurrencyVnd(entry.value.unitPrice)} / ${tariff.unit}');
            }),
          ],
          if (tariff.reason != null) Text('Lý do đề xuất: ${tariff.reason}'),
          if (tariff.reviewReason != null)
            Text('Lý do xử lý: ${tariff.reviewReason}'),
          if (tariff.makerId != null)
            Text('Người đề xuất: ${tariff.makerId}',
                style: Theme.of(context).textTheme.bodySmall),
          if (tariff.reviewedAt != null)
            Text(
                'Xử lý lúc ${tariff.reviewedAt!.toLocal().toIso8601String()} · ${tariff.checkerId ?? ''}',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _CompareValue extends StatelessWidget {
  const _CompareValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final normalized = state.toUpperCase();
    final color = switch (normalized) {
      'APPROVED' => AppTheme.green,
      'REJECTED' => AppTheme.red,
      _ => AppTheme.amber,
    };
    final label = switch (normalized) {
      'APPROVED' => 'Đã duyệt',
      'REJECTED' => 'Từ chối',
      _ => 'Chờ duyệt',
    };
    return Chip(
      label: Text(label),
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: .14),
      labelStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ]),
        ),
      );
}

Future<String?> _askReason(
  BuildContext context, {
  required String title,
  required String action,
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, action: action),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.action});
  final String title;
  final String action;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          maxLength: 500,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Lý do',
            hintText: 'Lý do được lưu vào audit.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                Navigator.pop(context, _controller.text.trim());
              }
            },
            child: Text(widget.action),
          ),
        ],
      );
}

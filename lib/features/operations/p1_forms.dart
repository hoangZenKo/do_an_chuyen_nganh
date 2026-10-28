import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import 'p1_providers.dart';

enum OperationFormKind { turnover, recurring, announcement, group, template }

const operationKinds = {
  'meter_reading': 'Ghi điện nước',
  'inspection': 'Kiểm tra phòng',
  'collection': 'Thu tiền',
  'cleaning': 'Vệ sinh',
  'renewal': 'Gia hạn hợp đồng'
};
const operationFrequencies = {
  'DAILY': 'Hàng ngày',
  'WEEKLY': 'Hàng tuần',
  'MONTHLY': 'Hàng tháng',
  'QUARTERLY': 'Hàng quý'
};

class OperationFormScreen extends ConsumerStatefulWidget {
  const OperationFormScreen({super.key, required this.kind});
  final OperationFormKind kind;
  @override
  ConsumerState<OperationFormScreen> createState() =>
      _OperationFormScreenState();
}

class _OperationFormScreenState extends ConsumerState<OperationFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _name = TextEditingController();
  final _interval = TextEditingController(text: '1');
  final _checklist = TextEditingController(
      text: 'Thực hiện công việc\nKiểm tra kết quả và xác nhận');
  final _tenants = <String>{};
  String? _propertyId;
  String? _roomId;
  String? _groupId;
  String? _templateId;
  String _audience = 'ALL_TENANTS';
  String _kind = 'meter_reading';
  String _frequency = 'MONTHLY';
  DateTime _date = DateTime.now();
  bool _scheduled = false;
  bool _saving = false;
  String? _error;

  String get _heading => switch (widget.kind) {
        OperationFormKind.turnover => 'Bắt đầu trả phòng',
        OperationFormKind.recurring => 'Tạo lịch định kỳ',
        OperationFormKind.announcement => 'Soạn thông báo',
        OperationFormKind.group => 'Tạo nhóm người thuê',
        OperationFormKind.template => 'Lưu mẫu thông báo',
      };

  @override
  void dispose() {
    for (final controller in [_title, _body, _name, _interval, _checklist]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _date.isBefore(now) ? now : _date,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 5));
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (time != null && mounted) {
      setState(() => _date =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  Future<void> _submit() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    if ((widget.kind == OperationFormKind.group || _audience == 'TENANTS') &&
        _tenants.isEmpty) {
      setState(() => _error = 'Chọn ít nhất một người thuê.');
      return;
    }
    if (_scheduled && !_date.isAfter(DateTime.now())) {
      setState(() => _error = 'Chọn thời gian gửi trong tương lai.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(p1OperationsApiProvider);
      switch (widget.kind) {
        case OperationFormKind.turnover:
          await api.startTurnover(_roomId!, note: _body.text.trim());
        case OperationFormKind.recurring:
          await api.createRecurring({
            'propertyId': _propertyId,
            if (_roomId != null) 'roomId': _roomId,
            'title': _title.text.trim(),
            'kind': _kind,
            'frequency': _frequency,
            'interval': int.parse(_interval.text),
            'nextRunAt': _date.toUtc().toIso8601String(),
            'checklist': _checklist.text
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty)
                .toList()
          });
        case OperationFormKind.announcement:
          await api.createAnnouncement({
            'title': _title.text.trim(),
            'body': _body.text.trim(),
            'audience': _audience,
            if (_audience == 'PROPERTY' || _audience == 'ROOM')
              'propertyId': _propertyId,
            if (_audience == 'ROOM') 'roomId': _roomId,
            if (_audience == 'GROUP') 'groupId': _groupId,
            if (_audience == 'TENANTS') 'tenantIds': _tenants.toList(),
            if (_scheduled) 'sendAt': _date.toUtc().toIso8601String()
          });
        case OperationFormKind.group:
          await api.createGroup(_name.text.trim(), _tenants.toList());
        case OperationFormKind.template:
          await api.createTemplate(
              _name.text.trim(), _title.text.trim(), _body.text.trim());
      }
      ref.invalidate(turnoversProvider);
      ref.invalidate(recurringTasksProvider);
      ref.invalidate(recurringSchedulesProvider);
      ref.invalidate(landlordAnnouncementsProvider);
      ref.invalidate(tenantGroupsProvider);
      ref.invalidate(announcementTemplatesProvider);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Vui lòng nhập nội dung.' : null;

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(operationOptionsProvider);
    return Scaffold(
        appBar: AppBar(title: Text(_heading)),
        body: options.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$error', textAlign: TextAlign.center),
            TextButton(
                onPressed: () => ref.invalidate(operationOptionsProvider),
                child: const Text('Tải lại'))
          ])),
          data: (data) {
            final properties =
                (data['properties'] as List).cast<Map<String, dynamic>>();
            final selected = properties
                .where((property) => property['id'] == _propertyId)
                .firstOrNull;
            final rooms = ((selected?['rooms'] as List?) ?? [])
                .cast<Map<String, dynamic>>()
                .where((room) =>
                    widget.kind != OperationFormKind.turnover ||
                    room['status'] != 'OCCUPIED')
                .toList();
            final tenants =
                (data['tenants'] as List).cast<Map<String, dynamic>>();
            final needsProperty = widget.kind == OperationFormKind.turnover ||
                widget.kind == OperationFormKind.recurring ||
                (widget.kind == OperationFormKind.announcement &&
                    ['PROPERTY', 'ROOM'].contains(_audience));
            final needsRoom = widget.kind == OperationFormKind.turnover ||
                (widget.kind == OperationFormKind.announcement &&
                    _audience == 'ROOM');
            return SafeArea(
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Form(
                            key: _form,
                            child: ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  if (widget.kind ==
                                      OperationFormKind.announcement) ...[
                                    ref
                                        .watch(announcementTemplatesProvider)
                                        .when(
                                            data: (templates) => DropdownButtonFormField<
                                                    String>(
                                                value: _templateId,
                                                isExpanded: true,
                                                decoration: const InputDecoration(
                                                    labelText:
                                                        'Dùng mẫu nội dung (tùy chọn)'),
                                                items: templates
                                                    .map((item) => DropdownMenuItem(
                                                        value: item['id']
                                                            as String,
                                                        child: Text(
                                                            item['name']
                                                                as String,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis)))
                                                    .toList(),
                                                onChanged: _saving
                                                    ? null
                                                    : (id) {
                                                        final template =
                                                            templates.firstWhere(
                                                                (item) =>
                                                                    item[
                                                                        'id'] ==
                                                                    id);
                                                        setState(() {
                                                          _templateId = id;
                                                          _title.text =
                                                              template['title']
                                                                  as String;
                                                          _body.text =
                                                              template['body']
                                                                  as String;
                                                        });
                                                      }),
                                            error: (error, _) => Text(
                                                'Không tải được mẫu: $error'),
                                            loading: () =>
                                                const LinearProgressIndicator()),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                        value: _audience,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Gửi đến'),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'ALL_TENANTS',
                                              child: Text('Tất cả người thuê')),
                                          DropdownMenuItem(
                                              value: 'PROPERTY',
                                              child: Text('Theo khu trọ')),
                                          DropdownMenuItem(
                                              value: 'ROOM',
                                              child: Text('Theo phòng')),
                                          DropdownMenuItem(
                                              value: 'GROUP',
                                              child:
                                                  Text('Theo nhóm người thuê')),
                                          DropdownMenuItem(
                                              value: 'TENANTS',
                                              child: Text('Chọn người thuê'))
                                        ],
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(() {
                                                  _audience = value!;
                                                  _propertyId = null;
                                                  _roomId = null;
                                                })),
                                    const SizedBox(height: 16),
                                    if (_audience == 'GROUP')
                                      ref.watch(tenantGroupsProvider).when(
                                          data: (groups) => DropdownButtonFormField<String>(
                                              value: _groupId,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                  labelText: 'Nhóm người thuê'),
                                              validator: _required,
                                              items: groups
                                                  .map((item) => DropdownMenuItem(
                                                      value:
                                                          item['id'] as String,
                                                      child: Text(
                                                          item['name']
                                                              as String,
                                                          overflow: TextOverflow
                                                              .ellipsis)))
                                                  .toList(),
                                              onChanged: _saving
                                                  ? null
                                                  : (value) =>
                                                      setState(() => _groupId = value)),
                                          error: (error, _) => Text('$error'),
                                          loading: () => const LinearProgressIndicator()),
                                  ],
                                  if (widget.kind == OperationFormKind.group ||
                                      widget.kind ==
                                          OperationFormKind.template) ...[
                                    TextFormField(
                                        controller: _name,
                                        validator: _required,
                                        maxLength: 120,
                                        decoration: InputDecoration(
                                            labelText: widget.kind ==
                                                    OperationFormKind.group
                                                ? 'Tên nhóm'
                                                : 'Tên mẫu')),
                                    const SizedBox(height: 16)
                                  ],
                                  if (needsProperty) ...[
                                    DropdownButtonFormField<String>(
                                        key: ValueKey('property-$_audience'),
                                        value: _propertyId,
                                        isExpanded: true,
                                        validator: _required,
                                        decoration: const InputDecoration(
                                            labelText: 'Khu trọ'),
                                        items: properties
                                            .map((property) => DropdownMenuItem(
                                                value: property['id'] as String,
                                                child: Text(
                                                    property['name'] as String,
                                                    overflow:
                                                        TextOverflow.ellipsis)))
                                            .toList(),
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(() {
                                                  _propertyId = value;
                                                  _roomId = null;
                                                })),
                                    const SizedBox(height: 16),
                                  ],
                                  if (needsRoom ||
                                      widget.kind ==
                                          OperationFormKind.recurring) ...[
                                    DropdownButtonFormField<String>(
                                        key: ValueKey('room-$_propertyId'),
                                        value: _roomId,
                                        isExpanded: true,
                                        validator: needsRoom ? _required : null,
                                        decoration: InputDecoration(
                                            labelText: needsRoom
                                                ? 'Phòng'
                                                : 'Phòng (không chọn = toàn khu)'),
                                        items: [
                                          if (!needsRoom)
                                            const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text('Toàn khu trọ')),
                                          ...rooms.map((room) =>
                                              DropdownMenuItem(
                                                  value: room['id'] as String,
                                                  child: Text(
                                                      room['name'] as String,
                                                      overflow: TextOverflow
                                                          .ellipsis)))
                                        ],
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(
                                                () => _roomId = value)),
                                    const SizedBox(height: 16),
                                  ],
                                  if (widget.kind ==
                                      OperationFormKind.recurring) ...[
                                    DropdownButtonFormField<String>(
                                        value: _kind,
                                        decoration: const InputDecoration(
                                            labelText: 'Loại công việc'),
                                        items: operationKinds.entries
                                            .map((entry) => DropdownMenuItem(
                                                value: entry.key,
                                                child: Text(entry.value)))
                                            .toList(),
                                        onChanged: _saving
                                            ? null
                                            : (value) =>
                                                setState(() => _kind = value!)),
                                    const SizedBox(height: 16),
                                  ],
                                  if ([
                                    OperationFormKind.recurring,
                                    OperationFormKind.announcement,
                                    OperationFormKind.template
                                  ].contains(widget.kind)) ...[
                                    TextFormField(
                                        controller: _title,
                                        validator: _required,
                                        maxLength: 160,
                                        decoration: const InputDecoration(
                                            labelText: 'Tiêu đề')),
                                    const SizedBox(height: 16)
                                  ],
                                  if ([
                                    OperationFormKind.turnover,
                                    OperationFormKind.announcement,
                                    OperationFormKind.template
                                  ].contains(widget.kind)) ...[
                                    TextFormField(
                                        controller: _body,
                                        validator: widget.kind ==
                                                OperationFormKind.turnover
                                            ? null
                                            : _required,
                                        minLines: 3,
                                        maxLines: 8,
                                        maxLength: widget.kind ==
                                                OperationFormKind.turnover
                                            ? 1000
                                            : 5000,
                                        decoration: InputDecoration(
                                            labelText: widget.kind ==
                                                    OperationFormKind.turnover
                                                ? 'Ghi chú (tùy chọn)'
                                                : 'Nội dung thông báo')),
                                    const SizedBox(height: 16)
                                  ],
                                  if (widget.kind ==
                                      OperationFormKind.recurring) ...[
                                    TextFormField(
                                        controller: _checklist,
                                        minLines: 3,
                                        maxLines: 8,
                                        decoration: const InputDecoration(
                                            labelText: 'Checklist',
                                            helperText:
                                                'Mỗi dòng là một bước, tối đa 20 bước.'),
                                        validator: (value) {
                                          final lines = (value ?? '')
                                              .split('\n')
                                              .map((line) => line.trim())
                                              .where((line) => line.isNotEmpty)
                                              .toList();
                                          return lines.isEmpty ||
                                                  lines.length > 20 ||
                                                  lines.any((line) =>
                                                      line.length > 200)
                                              ? 'Nhập 1–20 bước, tối đa 200 ký tự mỗi bước.'
                                              : null;
                                        }),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                        value: _frequency,
                                        decoration: const InputDecoration(
                                            labelText: 'Lặp lại'),
                                        items: operationFrequencies.entries
                                            .map((entry) => DropdownMenuItem(
                                                value: entry.key,
                                                child: Text(entry.value)))
                                            .toList(),
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(
                                                () => _frequency = value!)),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        controller: _interval,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Mỗi bao nhiêu chu kỳ?'),
                                        validator: (value) {
                                          final interval =
                                              int.tryParse(value ?? '') ?? 0;
                                          return interval < 1 || interval > 12
                                              ? 'Nhập số từ 1 đến 12.'
                                              : null;
                                        }),
                                    const SizedBox(height: 16),
                                  ],
                                  if (widget.kind == OperationFormKind.group ||
                                      (widget.kind ==
                                              OperationFormKind.announcement &&
                                          _audience == 'TENANTS')) ...[
                                    const Text('Người nhận',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    if (tenants.isEmpty)
                                      const Text(
                                          'Chưa có người thuê đang hoạt động.'),
                                    ...tenants.map((tenant) => CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title:
                                            Text(tenant['fullName'] as String),
                                        value: _tenants.contains(tenant['id']),
                                        onChanged: _saving
                                            ? null
                                            : (checked) => setState(() {
                                                  if (checked == true) {
                                                    _tenants.add(
                                                        tenant['id'] as String);
                                                  } else {
                                                    _tenants
                                                        .remove(tenant['id']);
                                                  }
                                                }))),
                                  ],
                                  if (widget.kind ==
                                      OperationFormKind.announcement)
                                    SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Hẹn giờ gửi'),
                                        subtitle: const Text(
                                            'Tắt để gửi ngay. Người nhận được chốt khi tạo thông báo.'),
                                        value: _scheduled,
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(
                                                () => _scheduled = value)),
                                  if (widget.kind ==
                                          OperationFormKind.recurring ||
                                      _scheduled)
                                    ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading:
                                            const Icon(Icons.event_rounded),
                                        title: Text(widget.kind ==
                                                OperationFormKind.recurring
                                            ? 'Lần đầu thực hiện'
                                            : 'Thời gian gửi'),
                                        subtitle: Text(
                                            '${formatDate(_date)} · ${TimeOfDay.fromDateTime(_date).format(context)}'),
                                        trailing: const Icon(
                                            Icons.edit_calendar_rounded),
                                        onTap: _saving ? null : _pickDate),
                                  if (_error != null)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Text(_error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error))),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                      onPressed: _saving ? null : _submit,
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.check_rounded),
                                      label: Text(_saving
                                          ? 'Đang lưu…'
                                          : widget.kind ==
                                                  OperationFormKind.announcement
                                              ? (_scheduled
                                                  ? 'Hẹn giờ gửi'
                                                  : 'Gửi thông báo')
                                              : 'Lưu')),
                                ])))));
          },
        ));
  }
}

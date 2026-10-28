import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../../models/p1_operations.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../rooms/room_providers.dart';
import 'p1_forms.dart';
import 'p1_providers.dart';

class P1OperationsScreen extends ConsumerStatefulWidget {
  const P1OperationsScreen({super.key, this.initialSection = 'turnovers'});
  final String initialSection;
  @override
  ConsumerState<P1OperationsScreen> createState() => _P1OperationsScreenState();
}

class _P1OperationsScreenState extends ConsumerState<P1OperationsScreen> {
  late String _section = widget.initialSection;
  int _page = 1;
  void _refresh() {
    ref.invalidate(turnoversProvider);
    ref.invalidate(recurringTasksProvider);
    ref.invalidate(recurringSchedulesProvider);
    ref.invalidate(landlordAnnouncementsProvider);
  }

  Future<void> _form(OperationFormKind kind) async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(
        builder: (_) => OperationFormScreen(kind: kind)));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    bool has(String permission) => sessionHasPermission(session, permission);
    final sections = <String, String>{
      if (has('room.view') || has('room.manage')) 'turnovers': 'Trả phòng',
      if (has('operation.view') || has('operation.manage')) ...{
        'tasks': 'Checklist',
        'schedules': 'Lịch định kỳ'
      },
      if (has('notification.view') || has('notification.manage'))
        'announcements': 'Thông báo'
    };
    final section =
        sections.containsKey(_section) ? _section : sections.keys.firstOrNull;
    final canCreate = section == 'turnovers'
        ? has('room.manage')
        : section == 'announcements'
            ? has('notification.manage')
            : has('operation.manage');
    return Scaffold(
      appBar: AppBar(title: const Text('Trung tâm vận hành'), actions: [
        IconButton(
            tooltip: 'Tải lại',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded)),
        if (section == 'announcements' && canCreate)
          PopupMenuButton<OperationFormKind>(
              tooltip: 'Mẫu và nhóm người nhận',
              onSelected: _form,
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: OperationFormKind.template,
                        child: Text('Tạo mẫu thông báo')),
                    PopupMenuItem(
                        value: OperationFormKind.group,
                        child: Text('Tạo nhóm người thuê'))
                  ])
      ]),
      body: section == null
          ? const Center(child: Text('Bạn chưa có quyền truy cập vận hành.'))
          : SafeArea(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(children: [
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                                children: sections.entries
                                    .map((entry) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                            label: Text(entry.value),
                                            selected: section == entry.key,
                                            onSelected: (_) => setState(() {
                                                  _section = entry.key;
                                                  _page = 1;
                                                }))))
                                    .toList())),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                      switch (section) {
                                        'turnovers' =>
                                          'Từ trả phòng đến sẵn sàng cho thuê',
                                        'tasks' =>
                                          'Việc cần làm theo từng lần thực hiện',
                                        'schedules' => 'Lịch tự sinh checklist',
                                        _ => 'Gửi đúng người, theo dõi đã đọc'
                                      },
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 8),
                                  Text(
                                      switch (section) {
                                        'turnovers' =>
                                          'Kết thúc hợp đồng sẽ tự tạo quy trình. Chỉ mở cho thuê sau khi hoàn tất kiểm tra, sửa chữa và vệ sinh.',
                                        'tasks' =>
                                          'Xác nhận từng bước sau khi đã thực hiện. Checklist không tự tạo hóa đơn hay thay thế việc ghi công tơ.',
                                        'schedules' =>
                                          'Hệ thống kiểm tra mỗi phút và tự tạo việc đến hạn, kể cả sau khi API khởi động lại.',
                                        _ =>
                                          'Thông báo hiển thị trong tài khoản người thuê. Danh sách người nhận được chốt khi tạo.'
                                      },
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                  if (canCreate) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: FilledButton.icon(
                                            onPressed: () => _form(
                                                section == 'turnovers'
                                                    ? OperationFormKind.turnover
                                                    : section == 'announcements'
                                                        ? OperationFormKind
                                                            .announcement
                                                        : OperationFormKind
                                                            .recurring),
                                            icon: const Icon(Icons.add_rounded),
                                            label: Text(section == 'turnovers'
                                                ? 'Bắt đầu trả phòng'
                                                : section == 'announcements'
                                                    ? 'Soạn thông báo'
                                                    : 'Tạo lịch định kỳ')))
                                  ]
                                ])),
                        Expanded(
                            child: switch (section) {
                          'turnovers' => ref
                              .watch(turnoversProvider(_page))
                              .when(
                                  loading: _loading,
                                  error: _error,
                                  data: (page) => _list(
                                      page.items
                                          .map((item) => _TurnoverCard(
                                              item: item,
                                              canManage: has('room.manage')))
                                          .toList(),
                                      total: page.total,
                                      hasNext: page.hasNext)),
                          'tasks' =>
                            ref.watch(recurringTasksProvider(_page)).when(
                                loading: _loading,
                                error: _error,
                                data: (page) => _list(
                                    page.items
                                        .map((item) => _TaskCard(
                                            item: item,
                                            canManage: has('operation.manage')))
                                        .toList(),
                                    total: page.total,
                                    hasNext: page.hasNext)),
                          'schedules' =>
                            ref.watch(recurringSchedulesProvider(_page)).when(
                                loading: _loading,
                                error: _error,
                                data: (page) => _list(
                                    page.items
                                        .map((item) => _ScheduleTile(
                                            item: item,
                                            canManage: has('operation.manage')))
                                        .toList(),
                                    total: page.total,
                                    hasNext: page.hasNext)),
                          _ => ref.watch(landlordAnnouncementsProvider).when(
                              loading: _loading,
                              error: _error,
                              data: (items) => _list(
                                  items
                                      .map((item) => ListTile(
                                          contentPadding:
                                              const EdgeInsets.all(16),
                                          title: Text(item.title,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700)),
                                          subtitle: Text(
                                              '${_announcementStatus(item.status)} · ${formatDate(item.sendAt.toLocal())}\n${item.readCount}/${item.recipientCount} đã đọc'),
                                          trailing: const Icon(
                                              Icons.chevron_right_rounded),
                                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                              builder: (_) => AnnouncementDetailScreen(
                                                  item: item,
                                                  canManage: has('notification.manage'))))))
                                      .toList(),
                                  total: items.length,
                                  hasNext: false)),
                        }),
                      ])))),
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());
  Widget _error(Object error, StackTrace stack) => Center(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refresh, child: const Text('Thử lại'))
          ])));
  Widget _list(List<Widget> items,
          {required int total, required bool hasNext}) =>
      RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (items.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text('Chưa có dữ liệu ở mục này.',
                          textAlign: TextAlign.center)),
                ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(child: item))),
                if (_section != 'announcements' && total > 20)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(
                        tooltip: 'Trang trước',
                        onPressed:
                            _page > 1 ? () => setState(() => _page--) : null,
                        icon: const Icon(Icons.chevron_left_rounded)),
                    Text('Trang $_page · $total mục'),
                    IconButton(
                        tooltip: 'Trang sau',
                        onPressed:
                            hasNext ? () => setState(() => _page++) : null,
                        icon: const Icon(Icons.chevron_right_rounded))
                  ])
              ]));
}

class _TurnoverCard extends ConsumerStatefulWidget {
  const _TurnoverCard({required this.item, required this.canManage});
  final RoomTurnover item;
  final bool canManage;
  @override
  ConsumerState<_TurnoverCard> createState() => _TurnoverCardState();
}

class _TurnoverCardState extends ConsumerState<_TurnoverCard> {
  bool _busy = false;
  Future<void> _advance() async {
    final note = await showDialog<String>(
        context: context,
        builder: (_) => _StepDialog(stage: widget.item.stage));
    if (note == null || !mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(p1OperationsApiProvider)
          .advanceTurnover(widget.item, note);
      ref.invalidate(roomsProvider);
      ref.invalidate(roomDetailProvider(widget.item.roomId));
      ref.invalidate(dashboardMetricsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      ref.invalidate(turnoversProvider);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.roomName, style: Theme.of(context).textTheme.titleLarge),
          Text(item.propertyName ?? '',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TurnoverStage.values
                  .map((stage) => Chip(
                      avatar: Icon(
                          stage.index < item.stage.index
                              ? Icons.check_rounded
                              : stage.icon,
                          size: 16),
                      label: Text(stage.label),
                      backgroundColor: stage == item.stage
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null))
                  .toList()),
          if (item.status == 'active' && widget.canManage) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _busy ? null : _advance,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.task_alt_rounded),
                label: Text('Hoàn tất: ${item.stage.label}'))
          ],
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Checklist và lịch sử'),
              children: [
                ...item.steps.map((step) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(step.completedAt == null
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle_rounded),
                    title: Text(step.title),
                    subtitle: step.completedAt == null
                        ? null
                        : Text(
                            '${formatDate(step.completedAt!.toLocal())}\n${step.note ?? ''}')))
              ])
        ]));
  }
}

class _StepDialog extends StatefulWidget {
  const _StepDialog({required this.stage});
  final TurnoverStage stage;
  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text('Hoàn tất ${widget.stage.label.toLowerCase()}'),
          content: Form(
              key: _form,
              child: TextFormField(
                  controller: _note,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Kết quả thực hiện',
                      hintText:
                          'Ghi kết quả kiểm tra hoặc xác nhận không cần sửa.'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ghi kết quả trước khi chuyển bước.'
                      : null)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _note.text.trim());
                  }
                },
                child: const Text('Xác nhận'))
          ]);
}

class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({required this.item, required this.canManage});
  final OperationTask item;
  final bool canManage;
  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _busy = false;
  Future<void> _check(int index, bool done) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(p1OperationsApiProvider)
          .checkTask(widget.item, index, done);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      ref.invalidate(recurringTasksProvider);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          Text(
              '${item.roomName ?? 'Toàn khu'} · ${formatDate(item.dueAt.toLocal())} · ${item.status == 'completed' ? 'Đã hoàn tất' : item.dueAt.isBefore(DateTime.now()) ? 'Đến hạn' : 'Chờ thực hiện'}'),
          ...item.checklist.asMap().entries.map((entry) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(entry.value.title),
              value: entry.value.done,
              onChanged: _busy || !widget.canManage
                  ? null
                  : (done) => _check(entry.key, done!)))
        ]));
  }
}

class _ScheduleTile extends ConsumerStatefulWidget {
  const _ScheduleTile({required this.item, required this.canManage});
  final RecurringOperation item;
  final bool canManage;
  @override
  ConsumerState<_ScheduleTile> createState() => _ScheduleTileState();
}

class _ScheduleTileState extends ConsumerState<_ScheduleTile> {
  bool _busy = false;
  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(p1OperationsApiProvider)
          .toggleRecurring(widget.item.id, enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      ref.invalidate(recurringSchedulesProvider);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
      title: Text(widget.item.title),
      subtitle: Text(
          '${operationFrequencies[widget.item.frequency] ?? widget.item.frequency}\nLần tới: ${formatDate(widget.item.nextRunAt.toLocal())}'),
      value: widget.item.isEnabled,
      onChanged: _busy || !widget.canManage ? null : _toggle);
}

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen(
      {super.key,
      required this.item,
      this.canManage = false,
      this.tenant = false});
  final AnnouncementItem item;
  final bool canManage;
  final bool tenant;
  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  bool _busy = false;
  late final _receipts = widget.tenant
      ? null
      : ref.read(p1OperationsApiProvider).receipts(widget.item.id);
  Future<void> _act() async {
    if (!widget.tenant) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Hủy lịch gửi?'),
                  content: const Text(
                      'Thông báo này sẽ không được gửi đến người thuê.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Giữ lịch')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Hủy lịch gửi'))
                  ]));
      if (confirmed != true || !mounted) {
        return;
      }
    }
    setState(() => _busy = true);
    try {
      if (widget.tenant) {
        await ref
            .read(p1OperationsApiProvider)
            .markAnnouncementRead(widget.item.id);
        ref.invalidate(tenantAnnouncementsProvider);
      } else {
        await ref
            .read(p1OperationsApiProvider)
            .cancelAnnouncement(widget.item.id);
        ref.invalidate(landlordAnnouncementsProvider);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Nội dung thông báo')),
      body: SafeArea(
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    Text(widget.item.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                        '${_announcementStatus(widget.item.status)} · ${formatDate(widget.item.sendAt.toLocal())}'),
                    const SizedBox(height: 24),
                    SelectableText(widget.item.body),
                    const SizedBox(height: 24),
                    if ((widget.tenant && !widget.item.isRead) ||
                        (!widget.tenant &&
                            widget.canManage &&
                            widget.item.status == 'scheduled'))
                      FilledButton(
                          onPressed: _busy ? null : _act,
                          child: Text(_busy
                              ? 'Đang xử lý…'
                              : widget.tenant
                                  ? 'Xác nhận đã đọc'
                                  : 'Hủy lịch gửi')),
                    if (!widget.tenant) ...[
                      const Divider(height: 40),
                      Text('Xác nhận đã đọc',
                          style: Theme.of(context).textTheme.titleLarge),
                      FutureBuilder<List<Map<String, dynamic>>>(
                          future: _receipts,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('${snapshot.error}');
                            }
                            if (!snapshot.hasData) {
                              return const LinearProgressIndicator();
                            }
                            return Column(
                                children: snapshot.data!
                                    .map((item) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text((item['tenant'] as Map<
                                            String,
                                            dynamic>)['fullName'] as String),
                                        subtitle: Text(item['readAt'] == null
                                            ? 'Chưa xác nhận'
                                            : 'Đã đọc: ${formatDate(DateTime.parse(item['readAt'] as String).toLocal())}'),
                                        leading: Icon(item['readAt'] == null
                                            ? Icons.mark_email_unread_outlined
                                            : Icons.mark_email_read_rounded)))
                                    .toList());
                          })
                    ]
                  ])))));
}

String _announcementStatus(String status) => switch (status) {
      'sent' => 'Đã gửi',
      'cancelled' => 'Đã hủy',
      _ => 'Đã hẹn giờ'
    };

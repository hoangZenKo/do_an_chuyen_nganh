import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import '../tenant_portal/tenant_portal_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_sla_policy_screen.dart';
import 'admin_case_timeline_dialog.dart';
import 'admin_inbox_filters.dart';
import 'admin_registry_screen.dart';

class AdminSupportCenterScreen extends ConsumerStatefulWidget {
  const AdminSupportCenterScreen(
      {super.key,
      this.userMode = false,
      this.initialTicketId,
      this.initialTab = 'tickets',
      this.initialFilters = const {}});
  final bool userMode;
  final String? initialTicketId;
  final String initialTab;
  final Map<String, String> initialFilters;
  @override
  ConsumerState<AdminSupportCenterScreen> createState() => _SupportState();
}

class _SupportState extends WorkflowState<AdminSupportCenterScreen> {
  late String? selectedId = widget.initialTicketId;
  late String tab = widget.initialTab;
  int page = 1, messagePage = 1;
  String assignment = 'all', status = 'all';
  String search = '';
  Map<String, dynamic> viewFilters = {};
  final searchInput = TextEditingController();
  final reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    final filters = adminInboxFilters(widget.initialFilters, incidents: false);
    assignment = filters.remove('assignment') ?? 'all';
    status = filters.remove('status') ?? 'all';
    search = filters.remove('search') ?? '';
    searchInput.text = search;
    viewFilters = filters;
    page = 1;
  }

  @override
  void didUpdateWidget(covariant AdminSupportCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Uri(queryParameters: oldWidget.initialFilters).query !=
        Uri(queryParameters: widget.initialFilters).query) {
      _applyFilters();
    }
    if (oldWidget.initialTicketId != widget.initialTicketId ||
        oldWidget.initialTab != widget.initialTab) {
      selectedId = widget.initialTicketId;
      tab = ['tickets', 'appeals', 'notifications', 'verification']
              .contains(widget.initialTab)
          ? widget.initialTab
          : 'tickets';
      messagePage = 1;
      reply.clear();
    }
  }

  Future<void> openCaseTimeline(Map<String, dynamic> ticket) async {
    final input =
        await form('Mục đích mở hồ sơ hỗ trợ', const [workflowReason]);
    if (input == null) return;
    final response =
        await command('/admin/support-cases/${ticket['id']}/timeline', input);
    if (!mounted || response == null || !active) return;
    await showDialog<void>(
        context: context,
        builder: (_) => AdminCaseTimelineDialog(
            data: workflowData(response), owner: workflowOwner));
  }

  Future<void> linkCaseResource(Map<String, dynamic> ticket) async {
    final kinds = <String, String>{
      if (can('admin.properties.view')) ...{
        'PROPERTY': 'Khu trọ',
        'ROOM': 'Phòng'
      },
      'LEASE': 'Hợp đồng',
      if (can('admin.finance.read')) 'INVOICE': 'Hóa đơn (chỉ đọc)',
      if (can('admin.operations.view')) 'INCIDENT': 'Sự cố vận hành',
    };
    final input = await form('Liên kết tài nguyên với hồ sơ', [
      WorkflowField('kind', 'Loại tài nguyên', choices: kinds),
      const WorkflowField('targetId', 'Mã tài nguyên (UUID)', maxLength: 36),
      workflowReason,
    ]);
    if (input == null) return;
    await command('/admin/support-cases/${ticket['id']}/links',
        {...input, 'version': ticket['version']});
  }

  Future<void> saveView() async {
    final input = await form('Lưu bộ lọc hỗ trợ', const [
      WorkflowField('name', 'Tên bộ lọc', minLength: 2, maxLength: 80)
    ]);
    if (input == null) return;
    await command('/support/views', {
      'name': input['name'],
      'filters': {
        ...viewFilters,
        'assignment': assignment,
        if (status != 'all') 'status': status,
        if (search.isNotEmpty) 'search': search,
      }
    });
  }

  Future<void> uploadAttachment(Map<String, dynamic> ticket) async {
    var internal = false;
    if (!widget.userMode) {
      final input = await form('Phạm vi file đính kèm', const [
        WorkflowField('visibility', 'Ai được xem file?', choices: {
          'public': 'Người gửi ticket và bộ phận hỗ trợ',
          'internal': 'Chỉ nội bộ hỗ trợ'
        })
      ]);
      if (input == null) return;
      internal = input['visibility'] == 'internal';
    }
    if (!active || busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
      if (!active || picked == null) return;
      final file = picked.files.single;
      if (file.path == null || file.size > 8 * 1024 * 1024) {
        throw StateError('Chọn ảnh/PDF tối đa 8 MB.');
      }
      await ref.read(uploadApiProvider).uploadSupportAttachment(
          '${ticket['id']}', file.path!, (ticket['version'] as num).toInt(),
          internal: internal);
      if (active) ref.invalidate(adminResourceProvider);
    } catch (error) {
      if (active) setState(() => failure = '$error');
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> openAttachment(Map attachment) async {
    if (!active || busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final url = await ref
          .read(uploadApiProvider)
          .accessUrl('/uploads/${attachment['filename']}');
      if (!active) return;
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw StateError('Không mở được file. Hãy thử lại.');
      }
    } catch (error) {
      if (active) setState(() => failure = '$error');
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> configureSkills() async {
    try {
      final response = await ref
          .read(adminApiProvider)
          .resource('/support/tickets/assignees');
      if (!active) return;
      final agents = workflowRows(response);
      if (agents.isEmpty) throw StateError('Chưa có admin có quyền hỗ trợ.');
      final input = await form('Kỹ năng và sức chứa hỗ trợ', [
        WorkflowField('userId', 'Admin', choices: {
          for (final agent in agents) '${agent['id']}': '${agent['fullName']}'
        }),
        const WorkflowField('categories', 'Kỹ năng (ngăn cách bằng dấu phẩy)',
            initial: 'GENERAL', maxLength: 120),
        const WorkflowField('maxOpen', 'Số ticket mở tối đa',
            initial: '20', maxLength: 3),
        workflowReason,
      ]);
      if (input == null) return;
      final categories = input['categories']!
          .split(',')
          .map((value) => value.trim().toUpperCase())
          .toSet()
          .toList();
      final capacity = int.tryParse(input['maxOpen']!);
      if (capacity == null ||
          capacity < 1 ||
          capacity > 100 ||
          categories.any((category) => !{
                'GENERAL',
                'BILLING',
                'LEASE',
                'MAINTENANCE',
                'ACCOUNT',
                'SAFETY'
              }.contains(category))) {
        throw StateError(
            'Kỹ năng: GENERAL, BILLING, LEASE, MAINTENANCE, ACCOUNT, SAFETY. Sức chứa từ 1–100.');
      }
      await command(
          '/support/skills/${input['userId']}',
          {
            'categories': categories,
            'maxOpen': capacity,
            'reason': input['reason']
          },
          patch: true);
    } catch (error) {
      if (active) setState(() => failure = '$error');
    }
  }

  @override
  void dispose() {
    reply.dispose();
    searchInput.dispose();
    super.dispose();
  }

  Future<void> createTicket() async {
    final input = await form('Gửi yêu cầu hỗ trợ', const [
      WorkflowField('subject', 'Tiêu đề', minLength: 3, maxLength: 160),
      WorkflowField('category', 'Loại yêu cầu', choices: {
        'GENERAL': 'Chung',
        'BILLING': 'Hóa đơn',
        'LEASE': 'Hợp đồng',
        'MAINTENANCE': 'Bảo trì',
        'ACCOUNT': 'Tài khoản',
        'SAFETY': 'An toàn'
      }),
      WorkflowField('body', 'Nội dung yêu cầu',
          minLength: 10, maxLength: 10000, lines: 4),
    ]);
    if (input == null) return;
    final result = await command('/support/tickets', input);
    if (result != null && active) {
      setState(() {
        selectedId = '${workflowData(result)['id']}';
        tab = 'tickets';
        messagePage = 1;
      });
    }
  }

  Future<void> send(Map<String, dynamic> ticket,
      {bool internal = false}) async {
    final body = reply.text.trim();
    if (body.isEmpty) return;
    final result = await command(
        '/support/tickets/${ticket['id']}/${internal ? 'notes' : 'replies'}',
        {'body': body, 'version': ticket['version']});
    if (result != null && active) {
      reply.clear();
      setState(() => messagePage = 1);
    }
  }

  Future<void> assign(Map<String, dynamic> ticket) async {
    try {
      final api = ref.read(adminApiProvider);
      final values = await Future.wait([
        api.resource('/support/tickets/assignees'),
        api.resource('/support/tickets/teams')
      ]);
      if (!active) return;
      final input = await form('Phân công và ưu tiên SLA', [
        WorkflowField('assigneeId', 'Người xử lý',
            initial: '${ticket['assigneeId'] ?? 'none'}',
            choices: {
              'none': 'Chưa phân công',
              for (final row in workflowRows(values[0]))
                '${row['id']}': '${row['fullName']}'
            }),
        WorkflowField('teamId', 'Nhóm hỗ trợ',
            initial: '${ticket['teamId'] ?? 'none'}',
            choices: {
              'none': 'Không chọn nhóm',
              for (final row in workflowRows(values[1]))
                '${row['id']}': '${row['name']}'
            }),
        WorkflowField('priority', 'Độ ưu tiên',
            initial: '${ticket['priority']}',
            choices: const {
              'LOW': 'Thấp',
              'NORMAL': 'Bình thường',
              'HIGH': 'Cao',
              'URGENT': 'Khẩn cấp'
            }),
        workflowReason,
      ]);
      if (input != null) {
        await command(
            '/support/tickets/${ticket['id']}/assignment',
            {
              ...input,
              'assigneeId':
                  input['assigneeId'] == 'none' ? null : input['assigneeId'],
              'teamId': input['teamId'] == 'none' ? null : input['teamId'],
              'version': ticket['version']
            },
            patch: true);
      }
    } catch (error) {
      if (active) setState(() => failure = '$error');
    }
  }

  Future<void> changeStatus(Map<String, dynamic> ticket, String value) async {
    final input = await form(
        'Chuyển trạng thái: ${workflowLabel(value)}', const [workflowReason]);
    if (input != null) {
      await command('/support/tickets/${ticket['id']}/status',
          {...input, 'status': value, 'version': ticket['version']},
          patch: true);
    }
  }

  Future<void> editLabels(Map<String, dynamic> ticket) async {
    final input = await form('Nhãn ticket', [
      WorkflowField('labels', 'Nhãn ngăn cách bằng dấu phẩy',
          initial: (ticket['labels'] as List? ?? []).join(', '),
          minLength: 0,
          maxLength: 330),
      workflowReason,
    ]);
    if (input == null) return;
    await command(
        '/support/tickets/${ticket['id']}/labels',
        {
          'labels': input['labels']!
              .split(',')
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
          'version': ticket['version'],
          'reason': input['reason'],
        },
        patch: true);
  }

  Future<void> feedback(Map<String, dynamic> ticket) async {
    final input = await form('Đánh giá hỗ trợ', const [
      WorkflowField('rating', 'Mức hài lòng', initial: '5', choices: {
        '5': '5 — Rất hài lòng',
        '4': '4 — Hài lòng',
        '3': '3 — Bình thường',
        '2': '2 — Chưa hài lòng',
        '1': '1 — Không hài lòng'
      }),
      WorkflowField('comment', 'Nhận xét',
          minLength: 0, maxLength: 2000, lines: 3),
    ]);
    if (input == null) return;
    await command('/support/tickets/${ticket['id']}/feedback', {
      'rating': int.parse(input['rating']!),
      'comment': input['comment'],
      'version': ticket['version']
    });
  }

  Future<void> useTemplate() async {
    try {
      final result =
          await ref.read(adminApiProvider).resource('/support/templates');
      if (!active) return;
      final rows =
          workflowRows(result).where((row) => row['isActive'] == true).toList();
      if (rows.isEmpty) {
        setState(() => failure = 'Chưa có mẫu đang hoạt động.');
        return;
      }
      final input = await form('Chọn mẫu phản hồi', [
        WorkflowField('id', 'Mẫu phản hồi', choices: {
          for (final row in rows) '${row['id']}': '${row['title']}'
        })
      ]);
      if (input != null && active) {
        reply.text =
            '${rows.firstWhere((row) => row['id'] == input['id'])['body']}';
      }
    } catch (error) {
      if (active) setState(() => failure = '$error');
    }
  }

  Future<void> createTemplate() async {
    final input = await form('Tạo mẫu phản hồi', const [
      WorkflowField('title', 'Tên mẫu', minLength: 2, maxLength: 120),
      WorkflowField('body', 'Nội dung', maxLength: 5000, lines: 4),
      workflowReason,
    ]);
    if (input != null) await command('/support/templates', input);
  }

  Future<void> mergeTicket(Map<String, dynamic> ticket) async {
    final input = await form('Gộp vào ticket cùng người yêu cầu', const [
      WorkflowField('targetId', 'Mã ticket đích'),
      WorkflowField('targetVersion', 'Version hiện tại của ticket đích'),
      workflowReason,
    ]);
    if (input == null) return;
    final version = int.tryParse(input['targetVersion']!);
    if (version == null || version < 1) {
      setState(() => failure = 'Version ticket đích phải là số nguyên dương.');
      return;
    }
    final result = await command('/support/tickets/${ticket['id']}/merge', {
      'targetId': input['targetId'],
      'targetVersion': version,
      'version': ticket['version'],
      'reason': input['reason'],
    });
    if (result != null && active) {
      setState(() => selectedId = input['targetId']);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = widget.userMode
        ? null
        : ref.watch(adminCapabilitiesProvider).valueOrNull;
    final manage = rights?.has('admin.support.manage') == true;
    final supportAccess =
        widget.userMode || rights?.has('admin.support.read') == true;
    return AdminWorkspaceScaffold(
      enabled: !widget.userMode,
      title: widget.userMode ? 'Trung tâm hỗ trợ' : 'Support Center',
      location: tab == 'notifications'
          ? '/admin/notifications'
          : '/admin/support-center',
      busy: busy,
      actions: widget.userMode
          ? [
              IconButton(
                  tooltip: 'Làm mới',
                  onPressed: () {
                    ref.invalidate(adminResourceProvider);
                    ref.invalidate(adminWorkspaceResourceProvider);
                  },
                  icon: const Icon(Icons.refresh)),
            ]
          : const [],
      body: !active
          ? const SizedBox.shrink()
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                color: AdminOverviewTheme.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (supportAccess)
                        ChoiceChip(
                            label: const Text('Yêu cầu hỗ trợ'),
                            selected: tab == 'tickets',
                            onSelected: (_) => setState(() => tab = 'tickets')),
                      if (widget.userMode &&
                          ref
                                  .watch(sessionControllerProvider)
                                  .session
                                  ?.user
                                  .role ==
                              'landlord')
                        ChoiceChip(
                            label: const Text('Xác minh chủ trọ'),
                            selected: tab == 'verification',
                            onSelected: (_) =>
                                setState(() => tab = 'verification')),
                      if (widget.userMode)
                        ChoiceChip(
                            label: const Text('Khiếu nại kiểm duyệt'),
                            selected: tab == 'appeals',
                            onSelected: (_) => setState(() => tab = 'appeals')),
                      if (widget.userMode ||
                          rights?.has('admin.notifications.view') == true)
                        ChoiceChip(
                            label: const Text('Thông báo'),
                            selected: tab == 'notifications',
                            onSelected: (_) =>
                                setState(() => tab = 'notifications')),
                      if (supportAccess)
                        FilledButton.icon(
                            onPressed: busy ? null : createTicket,
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo yêu cầu')),
                      if (manage)
                        TextButton(
                            onPressed: busy ? null : createTemplate,
                            child: const Text('Tạo mẫu phản hồi')),
                      if (manage && can('admin.admins.manage'))
                        TextButton(
                            onPressed: busy ? null : configureSkills,
                            child: const Text('Kỹ năng / sức chứa')),
                      if (manage && can('admin.admins.manage'))
                        TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const AdminSlaPolicyScreen())),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('Lịch làm việc / SLA')),
                    ]),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: operationState),
              ),
              if (tab == 'notifications') Expanded(child: notifications()),
              if (tab == 'appeals') Expanded(child: myAppeals()),
              if (tab == 'verification' &&
                  widget.userMode &&
                  ref.watch(sessionControllerProvider).session?.user.role ==
                      'landlord')
                const Expanded(
                    child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: LandlordVerificationPanel())),
              if (tab == 'tickets')
                Expanded(child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  if (!wide && selectedId != null) {
                    return Column(children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => selectedId = null),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Danh sách ticket'))),
                      Expanded(child: detail(manage))
                    ]);
                  }
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: wide ? 2 : 1, child: tickets()),
                        if (wide) ...[
                          const VerticalDivider(width: 1),
                          Expanded(
                              flex: 3,
                              child: selectedId == null
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: WorkflowEmpty(
                                          'Chọn ticket để xem hội thoại, SLA và phân công.',
                                          icon: Icons.support_agent_outlined))
                                  : detail(manage))
                        ]
                      ]);
                })),
            ]),
    );
  }

  Widget tickets() => ListView(padding: const EdgeInsets.all(16), children: [
        if (!widget.userMode && can('admin.support.manage'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: resource(
                const AdminRequest('/support/views'),
                (response) => Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final view in workflowRows(response))
                        ActionChip(
                            label: Text('${view['name']}'),
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                      final filters = Map<String, dynamic>.from(
                                          view['filters'] as Map);
                                      assignment =
                                          '${filters.remove('assignment') ?? 'all'}';
                                      status =
                                          '${filters.remove('status') ?? 'all'}';
                                      search =
                                          '${filters.remove('search') ?? ''}';
                                      searchInput.text = search;
                                      filters.remove('page');
                                      filters.remove('limit');
                                      viewFilters = filters;
                                      page = 1;
                                    })),
                      TextButton.icon(
                          onPressed: busy ? null : saveView,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Lưu bộ lọc')),
                      if (viewFilters.isNotEmpty)
                        TextButton(
                            onPressed: () => setState(() {
                                  viewFilters = {};
                                  page = 1;
                                }),
                            child: const Text('Bỏ lọc nâng cao')),
                    ])),
          ),
        TextField(
          controller: searchInput,
          decoration: const InputDecoration(
              isDense: true,
              labelText: 'Tìm tiêu đề hoặc nội dung',
              prefixIcon: Icon(Icons.search)),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => setState(() {
            search = value.trim();
            page = 1;
          }),
        ),
        const SizedBox(height: 10),
        AdminToolbarPanel(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            if (!widget.userMode)
              TextButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Sao chép bộ lọc'),
                  onPressed: () async {
                    final filters = {
                      ...viewFilters
                          .map((key, value) => MapEntry(key, '$value')),
                      if (assignment != 'all') 'assignment': assignment,
                      if (status != 'all') 'status': status,
                      if (search.isNotEmpty) 'search': search,
                    };
                    await Clipboard.setData(ClipboardData(
                        text: Uri(
                      path: '/admin/support-center',
                      queryParameters: filters,
                    ).toString()));
                    if (!mounted || !active) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã sao chép đường dẫn bộ lọc.')));
                  }),
            DropdownButton<String>(
                value: status,
                items: {
                  'all': 'Mọi trạng thái',
                  for (final value in [
                    'OPEN',
                    'IN_PROGRESS',
                    'WAITING_FOR_USER',
                    'RESOLVED',
                    'CLOSED'
                  ])
                    value: workflowLabel(value)
                }
                    .entries
                    .map((entry) => DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => setState(() {
                      status = value!;
                      page = 1;
                    })),
            if (!widget.userMode)
              DropdownButton<String>(
                  value: assignment,
                  items: const {
                    'all': 'Tất cả',
                    'mine': 'Của tôi',
                    'unassigned': 'Chưa giao',
                    'overdue': 'Quá hạn SLA'
                  }
                      .entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setState(() {
                        assignment = value!;
                        page = 1;
                      })),
            if (!widget.userMode) ...[
              DropdownButton<String>(
                  value: viewFilters['sla'] ?? 'all',
                  items: const {
                    'all': 'Mọi SLA',
                    'overdue': 'Đã quá SLA',
                    'due_soon': 'Đến hạn trong 1 giờ',
                    'paused': 'Đang tạm dừng SLA',
                  }
                      .entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setState(() {
                        viewFilters = {...viewFilters, 'sla': value};
                        page = 1;
                      })),
              DropdownButton<String>(
                  value: viewFilters['priority'] ?? 'all',
                  items: {
                    'all': 'Mọi độ ưu tiên',
                    for (final priority in ['LOW', 'NORMAL', 'HIGH', 'URGENT'])
                      priority: workflowLabel(priority),
                  }
                      .entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setState(() {
                        viewFilters = {...viewFilters}..remove('priority');
                        if (value != 'all') viewFilters['priority'] = value;
                        page = 1;
                      })),
              DropdownButton<String>(
                  value: viewFilters['sort'] ?? 'recent',
                  items: const {
                    'recent': 'Cập nhật gần nhất',
                    'oldest': 'Ticket cũ trước',
                    'resolution_due': 'Hạn giải quyết gần nhất',
                  }
                      .entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setState(() {
                        viewFilters = {...viewFilters, 'sort': value};
                        page = 1;
                      })),
            ],
          ],
        ),
        resource(
            AdminRequest('/support/tickets', {
              ...viewFilters,
              'page': page,
              'limit': 20,
              'assignment': assignment,
              if (search.isNotEmpty) 'search': search,
              if (status != 'all') 'status': status
            }),
            (response) => Column(children: [
                  if (workflowRows(response).isEmpty)
                    const WorkflowEmpty('Chưa có yêu cầu trong bộ lọc này.'),
                  for (final row in workflowRows(response))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: row['id'] == selectedId
                            ? AdminOverviewTheme.background
                            : AdminOverviewTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: row['id'] == selectedId
                              ? AdminOverviewTheme.blue.withValues(alpha: 0.6)
                              : AdminOverviewTheme.line,
                        ),
                      ),
                      child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          selected: row['id'] == selectedId,
                          title: Text(
                            '${row['subject']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                '${workflowLabel(row['status'])} · ${workflowLabel(row['priority'])}\nNgười xử lý: ${(row['assignee'] as Map?)?['fullName'] ?? 'Chưa giao'}\n'
                                '${row['firstRespondedAt'] == null ? 'Phản hồi trước: ${workflowDate(row['firstResponseDueAt'])} · ' : ''}'
                                '${row['slaPausedAt'] != null ? 'SLA đang tạm dừng' : 'Giải quyết trước: ${workflowDate(row['resolutionDueAt'])}'}'),
                          ),
                          onTap: () => setState(() {
                                selectedId = '${row['id']}';
                                messagePage = 1;
                                reply.clear();
                              })),
                    ),
                  WorkflowPager(
                      page: page,
                      total: ((response['meta'] as Map?)?['total'] as num?)
                              ?.toInt() ??
                          0,
                      limit: 20,
                      onPage: (value) => setState(() => page = value)),
                ])),
      ]);

  Widget detail(bool manage) => resource(
          AdminRequest('/support/tickets/$selectedId', {'page': messagePage}),
          (response) {
        final ticket = workflowData(response),
            state = '${workflowData(response)['status']}';
        const transitions = {
          'OPEN': ['IN_PROGRESS', 'RESOLVED'],
          'IN_PROGRESS': ['WAITING_FOR_USER', 'RESOLVED'],
          'WAITING_FOR_USER': ['IN_PROGRESS', 'RESOLVED'],
          'RESOLVED': ['OPEN', 'CLOSED'],
          'CLOSED': <String>[]
        };
        return Column(children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(20), children: [
            AdminSectionPanel(
              icon: Icons.confirmation_number_outlined,
              title: '${ticket['subject']}',
              subtitle:
                  '${workflowLabel(state)} · ${workflowLabel(ticket['priority'])}',
              trailing: Wrap(
                spacing: 6,
                children: [
                  AdminStatusBadge.fromStatus(state),
                  AdminStatusBadge.fromStatus(ticket['priority']),
                ],
              ),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                        'Phản hồi đầu: ${ticket['firstRespondedAt'] != null ? workflowDate(ticket['firstRespondedAt']) : 'Hạn ${workflowDate(ticket['firstResponseDueAt'])}'}'),
                    Text(
                        'Hạn giải quyết: ${workflowDate(ticket['resolutionDueAt'])}'),
                    SelectableText(
                        'Mã ticket: ${ticket['id']} · version ${ticket['version']}'),
                    if ((ticket['labels'] as List? ?? []).isNotEmpty)
                      Text('Nhãn: ${(ticket['labels'] as List).join(', ')}'),
                    if (ticket['feedbackRating'] != null)
                      Text('Đánh giá: ${ticket['feedbackRating']}/5'),
                  ],
                ),
                if (ticket['slaPausedAt'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Đồng hồ giải quyết đang tạm dừng từ ${workflowDate(ticket['slaPausedAt'])}; thời gian đã quá hạn không bị xóa.',
                      style: const TextStyle(color: AdminOverviewTheme.amber)),
                ],
                const SizedBox(height: 10),
                if (!widget.userMode && can('admin.support.read'))
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    TextButton.icon(
                        onPressed: busy ? null : () => openCaseTimeline(ticket),
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('Hồ sơ / timeline')),
                    if (manage && !['RESOLVED', 'CLOSED'].contains(state))
                      TextButton.icon(
                          onPressed:
                              busy ? null : () => linkCaseResource(ticket),
                          icon: const Icon(Icons.link_outlined),
                          label: const Text('Liên kết tài nguyên')),
                  ]),
                if (widget.userMode &&
                    ['RESOLVED', 'CLOSED'].contains(state) &&
                    ticket['feedbackAt'] == null &&
                    ticket['mergedIntoId'] == null)
                  TextButton(
                      onPressed: busy ? null : () => feedback(ticket),
                      child: const Text('Đánh giá hỗ trợ')),
                if (manage)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (ticket['assigneeId'] == null &&
                        can('admin.admins.manage') &&
                        !['RESOLVED', 'CLOSED'].contains(state))
                      TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final input = await form(
                                      'Tự động phân công theo kỹ năng / tải',
                                      const [workflowReason]);
                                  if (input != null) {
                                    await command(
                                        '/support/tickets/${ticket['id']}/auto-assign',
                                        {
                                          ...input,
                                          'version': ticket['version']
                                        });
                                  }
                                },
                          child: const Text('Tự động phân công')),
                    TextButton(
                        onPressed: busy ? null : () => editLabels(ticket),
                        child: const Text('Sửa nhãn')),
                    if (!['RESOLVED', 'CLOSED'].contains(state))
                      TextButton(
                          onPressed: busy ? null : () => mergeTicket(ticket),
                          child: const Text('Gộp ticket')),
                    TextButton.icon(
                        onPressed: busy ? null : () => assign(ticket),
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: const Text('Phân công / SLA')),
                    if ((transitions[state] ?? []).isNotEmpty)
                      PopupMenuButton<String>(
                          enabled: !busy,
                          onSelected: (value) => changeStatus(ticket, value),
                          itemBuilder: (_) => [
                                for (final value in transitions[state]!)
                                  PopupMenuItem(
                                      value: value,
                                      child: Text(workflowLabel(value)))
                              ],
                          child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Đổi trạng thái')))
                  ]),
              ],
            ),
            const SizedBox(height: 16),
            if (!['RESOLVED', 'CLOSED'].contains(state) &&
                ticket['mergedIntoId'] == null &&
                (manage || widget.userMode))
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: busy ? null : () => uploadAttachment(ticket),
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Đính kèm ảnh / PDF (tối đa 8 MB)'))),
            for (final attachment
                in (ticket['attachments'] as List? ?? []).whereType<Map>())
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AdminOverviewTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminOverviewTheme.line),
                ),
                child: ListTile(
                    dense: true,
                    leading: Icon(
                      attachment['internal'] == true
                          ? Icons.lock_outline
                          : Icons.attach_file,
                      color: attachment['internal'] == true
                          ? AdminOverviewTheme.amber
                          : AdminOverviewTheme.blue,
                    ),
                    title: Text(attachment['internal'] == true
                        ? 'File nội bộ'
                        : 'File đính kèm'),
                    subtitle: Text(
                        '${((attachment['size'] as num? ?? 0) / 1024).toStringAsFixed(1)} KB · ${workflowDate(attachment['createdAt'])}'),
                    onTap: busy ? null : () => openAttachment(attachment)),
              ),
            for (final message
                in (ticket['messages'] as List? ?? []).whereType<Map>())
              Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: message['internal'] == true
                        ? AdminOverviewTheme.amber.withValues(alpha: 0.1)
                        : AdminOverviewTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message['internal'] == true
                          ? AdminOverviewTheme.amber.withValues(alpha: 0.38)
                          : AdminOverviewTheme.line,
                    ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              message['internal'] == true
                                  ? Icons.lock_outline
                                  : Icons.chat_bubble_outline,
                              size: 16,
                              color: message['internal'] == true
                                  ? AdminOverviewTheme.amber
                                  : AdminOverviewTheme.blue),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  '${(message['author'] as Map?)?['fullName'] ?? message['authorRole']}${message['internal'] == true ? ' · Nội bộ' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)))
                        ]),
                        const SizedBox(height: 6),
                        SelectableText('${message['body']}'),
                        const SizedBox(height: 4),
                        Text(workflowDate(message['createdAt']),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AdminOverviewTheme.muted)),
                      ])),
            if (((response['messageMeta'] as Map?)?['total'] as num? ?? 0) > 50)
              WorkflowPager(
                  page: messagePage,
                  total: ((response['messageMeta'] as Map?)?['total'] as num?)
                          ?.toInt() ??
                      0,
                  limit: 50,
                  onPage: (value) => setState(() => messagePage = value)),
          ])),
          if (state != 'CLOSED' && (widget.userMode || manage))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: AdminSectionPanel(
                elevated: true,
                padding: const EdgeInsets.all(12),
                children: [
                  if (manage)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                            onPressed: busy ? null : useTemplate,
                            icon: const Icon(Icons.text_snippet_outlined),
                            label: const Text('Dùng mẫu phản hồi'))),
                  TextField(
                      controller: reply,
                      maxLength: 5000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Nội dung phản hồi',
                          hintText:
                              'Nội dung gửi sẽ hiển thị cho người yêu cầu. Ghi chú nội bộ chỉ admin thấy.')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                        onPressed: busy ? null : () => send(ticket),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Gửi phản hồi')),
                    if (manage)
                      OutlinedButton.icon(
                          onPressed:
                              busy ? null : () => send(ticket, internal: true),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Lưu ghi chú nội bộ'))
                  ]),
                ],
              ),
            ),
        ]);
      });

  Widget notifications() =>
      ListView(padding: const EdgeInsets.all(20), children: [
        AdminSectionPanel(
          icon: Icons.tune_outlined,
          title: 'Tùy chọn kênh thông báo',
          child:
              resource(const AdminRequest('/notification-center/preferences'),
                  (response) {
            final preferences = workflowData(response);
            return Column(children: [
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nhận thông báo qua email'),
                  subtitle: const Text(
                      'Cần cấu hình dịch vụ gửi email trên backend.'),
                  value: preferences['email'] == true,
                  onChanged: busy
                      ? null
                      : (value) => command('/notification-center/preferences',
                          {'email': value, 'push': preferences['push'] == true},
                          patch: true)),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nhận push notification'),
                  subtitle:
                      const Text('Cần nhà cung cấp push và đăng ký thiết bị.'),
                  value: preferences['push'] == true,
                  onChanged: busy
                      ? null
                      : (value) => command(
                          '/notification-center/preferences',
                          {
                            'email': preferences['email'] == true,
                            'push': value
                          },
                          patch: true)),
            ]);
          }),
        ),
        const SizedBox(height: 16),
        AdminSectionPanel(
          icon: Icons.notifications_active_outlined,
          title: 'Danh sách thông báo',
          trailing: TextButton(
              onPressed: busy
                  ? null
                  : () => command('/support/notifications/read-all', {}),
              child: const Text('Đánh dấu tất cả đã đọc')),
          child: resource(
              const AdminRequest('/support/notifications'),
              (response) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${(response['summary'] as Map?)?['unread'] ?? 0} thông báo chưa đọc · tối đa 100 thông báo mới nhất',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AdminOverviewTheme.muted),
                      ),
                      const SizedBox(height: 12),
                      if (workflowRows(response).isEmpty)
                        const WorkflowEmpty('Bạn chưa có thông báo.'),
                      for (final row in workflowRows(response))
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: row['readAt'] == null
                                ? AdminOverviewTheme.background
                                : AdminOverviewTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: row['readAt'] == null
                                  ? AdminOverviewTheme.blue
                                      .withValues(alpha: 0.4)
                                  : AdminOverviewTheme.line,
                            ),
                          ),
                          child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(
                                row['readAt'] == null
                                    ? Icons.mark_email_unread_outlined
                                    : Icons.drafts_outlined,
                                color: row['readAt'] == null
                                    ? AdminOverviewTheme.blue
                                    : AdminOverviewTheme.muted,
                              ),
                              title: Text(
                                '${row['title']}',
                                style: TextStyle(
                                  fontWeight: row['readAt'] == null
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                  '${row['body']}\n${workflowDate(row['createdAt'])}'),
                              trailing: row['readAt'] == null
                                  ? IconButton(
                                      tooltip: 'Đánh dấu đã đọc',
                                      onPressed: busy
                                          ? null
                                          : () => command(
                                              '/support/notifications/${row['id']}/read',
                                              {}),
                                      icon: const Icon(Icons.done))
                                  : null,
                              onTap: () {
                                final path = '${row['actionPath']}';
                                if (path.startsWith('/') &&
                                    !path.startsWith('//')) {
                                  context.go(path);
                                }
                              }),
                        ),
                    ],
                  )),
        ),
      ]);

  Widget myAppeals() => ListView(padding: const EdgeInsets.all(20), children: [
        AdminSectionPanel(
          icon: Icons.gavel_outlined,
          title: 'Quyết định của bạn',
          subtitle:
              'Có thể khiếu nại quyết định bất lợi trong 14 ngày; một lần cho mỗi quyết định.',
          child: resource(
              AdminRequest(
                  '/moderation/decisions', {'page': page, 'limit': 20}),
              (response) => Column(children: [
                    if (workflowRows(response).isEmpty)
                      const WorkflowEmpty('Chưa có quyết định kiểm duyệt.'),
                    for (final decision in workflowRows(response))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminOverviewTheme.line),
                        ),
                        child: ListTile(
                            title: Text(
                                '${decision['kind']} · ${decision['toStatus']}'),
                            subtitle: Text('${decision['reason']}'),
                            trailing: ['REJECTED', 'HIDDEN', 'DISMISSED']
                                    .contains(decision['toStatus'])
                                ? TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final input = await form(
                                                'Gửi khiếu nại / tranh chấp',
                                                const [workflowReason]);
                                            if (input != null) {
                                              await command(
                                                  '/moderation/appeals', {
                                                ...input,
                                                'decisionId': decision['id']
                                              });
                                            }
                                          },
                                    child: const Text('Khiếu nại'))
                                : null),
                      ),
                    WorkflowPager(
                        page: page,
                        total: ((response['meta'] as Map?)?['total'] as num?)
                                ?.toInt() ??
                            0,
                        limit: 20,
                        onPage: (value) => setState(() => page = value)),
                  ])),
        ),
        const SizedBox(height: 16),
        AdminSectionPanel(
          icon: Icons.rate_review_outlined,
          title: 'Khiếu nại đã gửi',
          child: resource(
              AdminRequest('/moderation/appeals', {'page': page, 'limit': 20}),
              (response) => Column(children: [
                    if (workflowRows(response).isEmpty)
                      const WorkflowEmpty('Bạn chưa gửi khiếu nại.'),
                    for (final appeal in workflowRows(response))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminOverviewTheme.line),
                        ),
                        child: ListTile(
                            title: Text(workflowLabel(appeal['status'])),
                            subtitle: Text(
                                '${appeal['reason']}\nHạn xét: ${workflowDate(appeal['dueAt'])}${appeal['resolution'] == null ? '' : '\nKết luận: ${appeal['resolution']}'}\n')),
                      ),
                  ])),
        ),
      ]);
}

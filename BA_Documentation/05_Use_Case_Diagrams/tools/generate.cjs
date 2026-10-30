const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const directory = path.resolve(__dirname, '..');
const root = path.resolve(directory, '../..');
const baselineDirectory = path.join(root, 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog');
const catalogFile = path.join(baselineDirectory, 'data/catalog.json');
const traceFile = path.join(baselineDirectory, 'data/traceability.json');
const catalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
const trace = JSON.parse(fs.readFileSync(traceFile, 'utf8'));
const byId = new Map(catalog.useCases.map(item => [item.id, item]));
const traceById = new Map(trace.useCases.map(item => [item.id, item]));
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const evidence = (file, symbol) => {
  const lines = fs.readFileSync(path.join(root, file), 'utf8').split('\n');
  const index = lines.findIndex(line => line.includes(symbol));
  if (index < 0) throw new Error('Missing evidence: ' + file + ' ' + symbol);
  return { file, line: index + 1, symbol };
};
const variants = [
  ['UC-DIS-08', 'A04', 'chỉ xem khung giờ', 'HousingController.slots'],
  ['UC-TNT-12.2', 'A04', 'chỉ xem biên bản', 'HousingController.handover'],
  ['UC-OPT-09', 'A03', 'chỉ đọc phí/phien bản', 'RoomsController.serviceFees'],
  ['UC-STF-01', 'A03', 'chỉ đọc nhân viên/preset', 'StaffController.list'],
  ['UC-BIL-16', 'A03', 'chỉ đọc tác động', 'BillingController.tariffImpact'],
  ['UC-TEN-05', 'A01', 'checkout: token DEMO hợp lệ', 'DemoCardPaymentController.checkout'],
  ['UC-DIS-15', 'A05', 'chỉ ngữ cảnh ownerId của mình', 'MyModerationController.decisions'],
].map(([ucId, actorId, label, binding]) => ({ ucId, actorId, label, binding }));
variants.find(item => item.ucId === 'UC-OPT-09').label = 'chỉ đọc phí/phiên bản';
const diagrams = [];
const group = id => catalog.groups.find(item => item.id === id);
const functionIds = (id, positions) => positions.flatMap(position => catalog.functions[id][position][1]);
function detail(file, groupId, ids, subtitle) {
  diagrams.push({ id: file, file: file + '.puml', kind: 'module', groupId, title: groupId + ' · ' + group(groupId).name, subtitle: subtitle || 'Đầy đủ UC của nhóm nghiệp vụ', ucIds: ids });
}
for (const item of catalog.groups) {
  if (item.id === 'G01') {
    detail('UC_G01_01_SYS_Public', item.id, ['UC-SYS-01', 'UC-SYS-02', 'UC-SYS-03', 'UC-SYS-06', 'UC-SYS-08', 'UC-SYS-09', 'UC-SYS-10'], 'Trang 1/2 · Đăng ký, đăng nhập và truy cập bằng liên kết');
    detail('UC_G01_02_SYS_Sessions', item.id, ['UC-SYS-05.1', 'UC-SYS-05.2', 'UC-SYS-07', 'UC-ADM-07.1'], 'Trang 2/2 · Phiên đăng nhập, mật khẩu và MFA');
  } else if (item.id === 'G06') {
    detail('UC_G06_01_Tenant_Records', item.id, functionIds(item.id, [0]), 'Trang 1/2 · Hồ sơ và tài khoản người thuê');
    detail('UC_G06_02_Leases_Deposits', item.id, functionIds(item.id, [1, 2]), 'Trang 2/2 · Hợp đồng, tiền cọc và người ở cùng');
  } else if (item.id === 'G08') {
    detail('UC_G08_01_Invoices', item.id, functionIds(item.id, [0, 1]), 'Trang 1/4 · Chỉ số, phát hành và điều chỉnh hóa đơn');
    detail('UC_G08_02_Collections', item.id, functionIds(item.id, [2, 3]), 'Trang 2/4 · Khoản thu, phân bổ và chứng từ thanh toán');
    detail('UC_G08_03_Tariffs_Periods', item.id, functionIds(item.id, [4]), 'Trang 3/4 · Biểu phí và khóa kỳ');
    detail('UC_G08_04_Reminders', item.id, functionIds(item.id, [5]), 'Trang 4/4 · Chính sách nhắc nợ và giao nhận');
  } else {
    detail('UC_' + item.id, item.id, catalog.functions[item.id].flatMap(item => item[1]));
  }
}
diagrams.unshift({ id: 'Overall_Use_Case', file: 'Overall_Use_Case.puml', kind: 'overall', groupId: null, title: 'TỔNG THỂ · HỆ THỐNG QUẢN LÝ NHÀ TRỌ', subtitle: '12 mục tiêu đại diện · Xem các sơ đồ G01–G16 để bao phủ đủ 162 UC', ucIds: ['UC-SYS-03', 'UC-DIS-01', 'UC-DIS-09', 'UC-TEN-03', 'UC-TNT-05', 'UC-TNT-08', 'UC-BIL-16', 'UC-OPT-03.1', 'UC-OPT-01', 'UC-ADM-02', 'UC-ADM-11', 'UC-ADM-15'] });
const staffIds = catalog.useCases.filter(item => item.primaryActorIds.includes('A03')).map(item => item.id);
const staffPages = [
  ['Phiên và phạm vi nhân sự', ['G01', 'G05'], null, ['UC-STF-01']],
  ['Khu trọ, phòng và tài sản', ['G04'], null, ['UC-OPT-09']],
  ['Hồ sơ, hợp đồng và tiền cọc', ['G06'], null, []],
  ['Vòng đời thuê, bảo trì và báo cáo', ['G07', 'G09', 'G11'], null, []],
  ['Chỉ số, hóa đơn và khoản thu', ['G08'], functionIds('G08', [0, 1, 2]), []],
  ['Chứng từ, biểu phí và nhắc nợ', ['G08'], functionIds('G08', [3, 4, 5]), ['UC-BIL-16']],
];
staffPages.forEach(([title, groups, allowed, extra], index) => {
  const ids = staffIds.filter(id => groups.includes(byId.get(id).businessGroup) && (!allowed || allowed.includes(id))).concat(extra);
  const name = 'Actor_A03_' + String(index + 1).padStart(2, '0');
  diagrams.push({ id: name, file: name + '.puml', kind: 'actor', actorId: 'A03', groupId: null, title: 'A03 · NHÂN VIÊN VẬN HÀNH', subtitle: 'Trang ' + (index + 1) + '/6 · ' + title, ucIds: ids });
});
const aclEvidence = [
  evidence('backend/src/common/roles.guard.ts', 'getAllAndOverride<AuthRole[]>'),
  evidence('backend/src/common/roles.guard.ts', 'requiredPermissions.some'),
  evidence('backend/src/common/admin-access.ts', 'required.filter'),
  evidence('backend/src/common/property-scope.ts', 'const scopedControllers'),
  evidence('backend/src/common/property-scope.ts', "if (controller === 'StaffController')"),
  evidence('backend/src/common/property-scope.ts', "['outboxEvents', 'retryOutbox']"),
];
function associationsFor(diagram) {
  const associations = [];
  for (const id of diagram.ucIds) {
    const item = byId.get(id);
    const source = traceById.get(id);
    for (const actorId of item.primaryActorIds.filter(actorId => diagram.kind !== 'actor' || diagram.actorId === actorId)) {
      const staffHandlers = source.handlers.filter(handler => handler.staffAllowedAfterInterceptor !== false && (handler.roles.includes('STAFF') || handler.binding.startsWith('AuthController.')));
      const staffPermissions = [...new Set(staffHandlers.flatMap(handler => handler.staffPermissions))];
      const label = diagram.kind === 'actor' && staffPermissions.length ? 'tùy handler: ' + staffPermissions.join(' / ') : '';
      associations.push({ actorId, ucId: id, kind: 'primary', label, matrix: item.matrix[actorId], condition: [item.matrix[actorId], item.rule, item.notes].filter(Boolean).join(' | '), evidence: source.handlers.filter(handler => { const role = catalog.actors.find(actor => actor.id === actorId).role; return actorId === 'A03' ? handler.staffAllowedAfterInterceptor === true || handler.binding.startsWith('AuthController.') : !role ? !handler.roles.startsWith('Roles(') : handler.roles.includes(role) || !handler.roles.startsWith('Roles('); }).concat(source.localEvidence).map(entry => ({ ...entry })), authorizationEvidence: aclEvidence });
    }
    if (diagram.kind !== 'overall') {
      for (const variant of variants.filter(variant => variant.ucId === id && (diagram.kind !== 'actor' || diagram.actorId === variant.actorId))) {
        const handler = source.handlers.find(handler => handler.binding === variant.binding) || trace.routes.find(handler => handler.binding === variant.binding);
        if (!handler || !item.matrix[variant.actorId].startsWith('V')) throw new Error('Unverified variant: ' + id);
        associations.push({ actorId: variant.actorId, ucId: id, kind: 'limited', label: variant.label, matrix: item.matrix[variant.actorId], condition: item.matrix[variant.actorId] + ' | ' + item.notes, evidence: [{ file: handler.file, line: handler.line, binding: variant.binding }], authorizationEvidence: aclEvidence });
      }
      for (const actorId of item.supportingActorIds.filter(actorId => !(diagram.kind === 'actor' && diagram.actorId === 'A03' && actorId === 'E02'))) {
        const actor = catalog.externalActors.find(actor => actor.id === actorId);
        associations.push({ actorId, ucId: id, kind: 'supporting', label: 'nếu cấu hình/bật', condition: 'Adapter có code; không chứng minh đã kết nối dịch vụ production. ' + item.notes, evidence: (actorId === 'E01' && id === 'UC-BIL-18.2' ? [...actor.evidence, 'backend/src/billing/billing-outbox.service.ts'] : actorId === 'E05' ? [...actor.evidence, 'backend/src/platform/report-object-storage.service.ts'] : actor.evidence).map(file => evidence(file, file.endsWith('billing-reminders.service.ts') ? 'billingOutboxEvent.createMany' : actorId === 'E03' && file.endsWith('support-attachment.service.ts') ? 'scanner.scan' : actorId === 'E05' && file.endsWith('admin-report-worker.service.ts') ? 'this.storage.' : 'fetch(')), authorizationEvidence: [] });
      }
    }
  }
  return associations;
}
function wrap(text, width = 31) {
  const lines = [''];
  for (const word of text.split(' ')) {
    if (lines[lines.length - 1].length + word.length + 1 > width) lines.push(word);
    else lines[lines.length - 1] += (lines[lines.length - 1] ? ' ' : '') + word;
  }
  return lines.join('\\n');
}
const alias = id => id.replaceAll('-', '_').replaceAll('.', '_');
const quote = value => value.replaceAll('"', '\\"');
function plantuml(diagram) {
  const usedActors = new Set(diagram.associations.map(item => item.actorId));
  const human = catalog.actors.filter(actor => usedActors.has(actor.id));
  const external = catalog.externalActors.filter(actor => usedActors.has(actor.id));
  const hasStaff = usedActors.has('A03');
  const hasAdmin = usedActors.has('A05');
  const hasLimited = diagram.associations.some(item => item.kind === 'limited');
  const lines = [
    '@startuml', 'left to right direction',
    'skinparam defaultFontName SansSerif', 'skinparam defaultFontSize 13',
    'skinparam backgroundColor #F8FAFC', 'skinparam shadowing false',
    'skinparam ArrowColor #52647A', 'skinparam ArrowThickness 1',
    'skinparam actorStyle stickman', 'skinparam actorBorderColor #243A52',
    'skinparam actorFontColor #243A52', 'skinparam actorBackgroundColor #FFFFFF',
    'skinparam usecase {', '  BackgroundColor #FFFFFF', '  BorderColor #327C83', '  FontColor #20354B',
    '  BackgroundColor<<Một phần>> #FFF0CE', '  BorderColor<<Một phần>> #B17917',
    '  BackgroundColor<<DEMO>> #FCE5DF', '  BorderColor<<DEMO>> #BC593A',
    '  BackgroundColor<<MÔ PHỎNG>> #E7EAF1', '  BorderColor<<MÔ PHỎNG>> #6C7488', '}',
    'skinparam rectangle {', '  BackgroundColor #EEF4F5', '  BorderColor #243A52', '  FontColor #243A52', '}',
    'skinparam titleFontColor #20354B', 'skinparam titleFontSize 18',
    'skinparam nodesep 25', 'skinparam ranksep 65',
    'title ' + diagram.title + '\\n<size:12>' + diagram.subtitle + '</size>',
    'caption AS-IS · 29/10/2026 · Snapshot c565c29 · Không biểu diễn trình tự xử lý',
  ];
  for (const actor of human) lines.push('actor "' + actor.id + '\\n' + wrap(actor.name, 23) + '" as ' + actor.id);
  lines.push('rectangle "Hệ thống quản lý nhà trọ" as SYSTEM {');
  for (const id of diagram.ucIds) {
    const item = byId.get(id);
    const status = item.status === 'Một phần' ? ' <<Một phần>>' : item.status.includes('DEMO') ? ' <<DEMO>>' : item.status.includes('MÔ PHỎNG') ? ' <<MÔ PHỎNG>>' : '';
    lines.push('  usecase "' + id + '\\n' + quote(wrap(item.title)) + '" as ' + alias(id) + status);
  }
  lines.push('}');
  for (const actor of external) lines.push('actor "' + actor.id + '\\n' + wrap(actor.name, 24) + '\\n(có điều kiện)" as ' + actor.id);
  const rightActorIds = new Set(diagram.kind === 'module' && usedActors.has('A02') ? ['A03'] : diagram.id === 'UC_G02' ? ['A04'] : []);
  for (const link of diagram.associations) {
    if (link.kind === 'supporting') lines.push(alias(link.ucId) + ' -- ' + link.actorId + ' : ' + link.label);
    else {
      const ends = rightActorIds.has(link.actorId) ? [alias(link.ucId), link.actorId] : [link.actorId, alias(link.ucId)];
      lines.push(ends[0] + (link.kind === 'limited' ? ' -[#3975AA]- ' : ' -- ') + ends[1] + (link.label ? ' : ' + link.label : ''));
    }
  }
  lines.push('legend bottom left', '  Đường liền: tương tác; không biểu diễn luồng điều khiển.');
  if (hasStaff) lines.push('  STAFF: permission theo handler + khu được giao + whitelist controller; không mặc định toàn quyền.');
  if (hasAdmin) lines.push('  ADMIN: capability theo handler + MFA/step-up nếu áp dụng; không kế thừa quyền chủ trọ.');
  if (hasLimited) lines.push('  Đường xanh có nhãn: biến thể giới hạn (V), không được toàn bộ mục tiêu UC.');
  if (diagram.ucIds.includes('UC-BIL-18.2')) lines.push('  Nhắc nợ: STAFF chỉ BillingController + billing.policy + propertyId; ZNS trực tiếp chỉ Chủ trọ.');
  if (external.length) lines.push('  E01–E05: hệ thống ngoài có adapter; chỉ tương tác ở nhánh cấu hình/bật tương ứng.');
  lines.push('  Mặc định: xác minh tĩnh, chưa nghiệm thu runtime; màu vàng: một phần, cam: DEMO, xám: mô phỏng.');
  if (diagram.kind === 'actor') lines.push('  Góc nhìn A03: nhãn liệt kê quyền tùy handler, KHÔNG yêu cầu đồng thời mọi quyền; giữ nguyên UC.');
  lines.push('  Quyền chi tiết, điều kiện và nguồn: Association_Traceability.md / data/diagram-manifest.json.', 'endlegend', '@enduml', '');
  return lines.join('\n');
}
for (const diagram of diagrams) {
  diagram.associations = associationsFor(diagram);
  diagram.actorIds = [...new Set(diagram.associations.map(item => item.actorId))];
  diagram.relationships = [];
}
const manifest = { schemaVersion: 1, date: '2026-10-29', snapshotCommit: catalog.snapshotCommit, catalogSha256: hash(catalogFile), traceabilitySha256: hash(traceFile), systemBoundary: 'Hệ thống quản lý nhà trọ', policy: { include: 'Không đủ bằng chứng hành vi bắt buộc tái sử dụng giữa các UC độc lập.', extend: 'Không đủ bằng chứng extension point giữa các UC Catalog.', generalization: 'Không có quan hệ thay thế/kế thừa quyền được chứng minh.', variants: 'Chỉ vẽ V có handler cụ thể; loại truy cập công khai gián tiếp và bước đã có UC riêng.' }, variants, diagrams };
function write(file, text) {
  const target = path.join(directory, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, text);
}
for (const diagram of diagrams) write(diagram.file, plantuml(diagram));
write('data/diagram-manifest.json', JSON.stringify(manifest, null, 2) + '\n');
const reference = entry => '\x60' + path.join(root, entry.file) + ':' + entry.line + '\x60';
const cell = text => String(text || '—').replaceAll('|', '/').replaceAll('\n', ' ');
const linkTo = diagram => '[' + diagram.id + '](' + diagram.file + ')';
const rows = ['# Truy vết UC → sơ đồ → triển khai', '', 'Ngày: 29/10/2026. Danh sách nguồn: Catalog Giai đoạn 2; không đổi mã/tên/nhóm/trạng thái.', '', '| Mã UC | Tên UC | Nhóm | Sơ đồ chi tiết sở hữu | Actor chính | Phối hợp | Trạng thái | Bằng chứng triển khai |', '| --- | --- | --- | --- | --- | --- | --- | --- |'];
for (const item of catalog.useCases) {
  const source = traceById.get(item.id);
  const diagram = diagrams.find(diagram => diagram.kind === 'module' && diagram.ucIds.includes(item.id));
  const entries = [...source.handlers.slice(0, 2), ...source.services.slice(0, 2), ...source.localEvidence.slice(0, 2)];
  rows.push('| ' + [item.id, item.title, item.businessGroup, linkTo(diagram), item.primaryActorIds.join(', '), item.supportingActorIds.join(', ') || '—', item.status, entries.map(reference).join('; ')].map(cell).join(' | ') + ' |');
}
rows.push('', '## Các lớp bằng chứng không rút gọn', '', 'Toàn bộ handler, Service, DTO, model, UI và test liên quan (chưa chạy lại) nằm trong data/traceability.json và 07_Traceability_and_Coverage.md của Giai đoạn 2. Mỗi association và điều kiện được lưu riêng ở data/diagram-manifest.json; bảng này không giả định một quyền áp dụng cho mọi endpoint của UC.', '');
write('UC_Diagram_Traceability.md', rows.join('\n'));
const edgeRows = ['# Truy vết Association và điều kiện tham gia', '', 'Đường liên kết không đồng nghĩa được thực hiện mọi thao tác của UC. P/P*: Actor chính có điều kiện; V: biến thể hạn chế; E: phối hợp ngoài có điều kiện. Role decorator riêng lẻ không đủ kết luận.', '', 'ADMIN: mọi capability bắt buộc trong cùng handler (ALL); STAFF: một trong các permission của handler (ANY), rồi whitelist/scope/service. Tập quyền của nhiều handler không được ghép thành điều kiện AND của cả UC.', '', 'Không nhân bản các dòng lặp ở overview/góc nhìn A03. Bảng dưới lấy associations của các sơ đồ module sở hữu.', '', '| Nhóm | UC | Actor | Loại | Nhãn/điều kiện | Bằng chứng gần nhất |', '| --- | --- | --- | --- | --- | --- |'];
for (const diagram of diagrams.filter(item => item.kind === 'module')) for (const edge of diagram.associations) edgeRows.push('| ' + [diagram.groupId, edge.ucId, edge.actorId, edge.kind, [edge.label, edge.matrix, edge.kind === 'supporting' ? edge.condition : ''].filter(Boolean).join('; '), edge.evidence.slice(0, 2).map(reference).join('; ')].map(cell).join(' | ') + ' |');
edgeRows.push('', '## V không vẽ riêng và lý do', '', '| UC | Actor | Điều kiện trong Matrix | Quyết định |', '| --- | --- | --- | --- |');
for (const item of catalog.useCases) for (const [actorId, value] of Object.entries(item.matrix)) if (value.startsWith('V') && !variants.some(variant => variant.ucId === item.id && variant.actorId === actorId)) edgeRows.push('| ' + [item.id, actorId, value, 'Không tạo association của mục tiêu toàn UC: chỉ truy cập công khai gián tiếp, đọc cấu hình phụ, hoặc hành vi đã biểu diễn tại UC riêng theo Matrix. Không biến V thành P.'].map(cell).join(' | ') + ' |');
edgeRows.push('', '## Bị chặn không phải Actor tham gia', '', 'Các ô B của A03 được giữ ở Actor_Coverage_Index.md, không tạo đường association. Đặc biệt: lời mời người thuê, công việc P1, thông báo, audit, hỗ trợ, upload và outbox không tự được cấp cho STAFF.', '', 'Các lớp chứng cứ phân quyền chung:', ...aclEvidence.map(entry => '- ' + reference(entry) + ': ' + entry.symbol), '');
write('Association_Traceability.md', edgeRows.join('\n'));
const actorRows = ['# Chỉ mục đầy đủ theo Actor', '', 'Mục đích: tra mọi UC Actor có thể khởi xướng và các ngoại lệ, không tạo thêm Actor hoặc UC. A04 dùng cùng role TENANT ở ngữ cảnh tìm phòng và đã thuê. Một User có một role, không có kế thừa ADMIN→LANDLORD hay STAFF→LANDLORD.', '', 'A03 có sáu sơ đồ chuyên biệt vì dễ nhầm quyền read-only và quyền bị interceptor chặn. A01/A02/A04 không thêm sơ đồ lặp; A05 đã có các trang quản trị tập trung theo G11–G16/G01. Bảng dưới cùng Actor–UC Matrix Giai đoạn 2 cung cấp phạm vi đầy đủ, không suy quyền từ sơ đồ tổng thể.', ''];
for (const actor of catalog.actors) {
  const primary = catalog.useCases.filter(item => item.primaryActorIds.includes(actor.id));
  actorRows.push('## ' + actor.id + ' — ' + actor.name, '', 'Role: ' + (actor.role || 'không đăng nhập, không có role GUEST') + '. Actor chính trong **' + primary.length + ' UC**.', '', '| UC | Mục tiêu | Mức tham gia | Trang module |', '| --- | --- | --- | --- |');
  for (const item of catalog.useCases.filter(item => item.matrix[actor.id] !== '—')) {
    const owner = diagrams.find(diagram => diagram.kind === 'module' && diagram.ucIds.includes(item.id));
    actorRows.push('| ' + [item.id, item.title, item.matrix[actor.id], linkTo(owner)].map(cell).join(' | ') + ' |');
  }
  actorRows.push('');
}
write('Actor_Coverage_Index.md', actorRows.join('\n'));
const index = ['# Giai đoạn 3 — UML Use Case AS-IS', '', 'Ngày: 29/10/2026 · Git: ' + catalog.snapshotCommit + '.', '', '## Phạm vi', '', '- 162 UC nguồn trong 16 nhóm G01–G16; giữ nguyên toàn bộ mã, tên, mục tiêu, Actor và trạng thái của Catalog Giai đoạn 2.', '- 28 sơ đồ độc lập: 1 tổng thể (12 UC đại diện), 21 trang module và 6 góc nhìn STAFF. Module lớn phân trang để đọc, không tách/gộp hay chuyển nhóm UC.', '- Mỗi UC xuất hiện đúng một lần trong bộ trang module; lặp có chủ đích ở tổng thể và góc nhìn A03 không là UC trùng Catalog.', '- Giữ 151 UC xác minh tĩnh, 9 một phần, 1 DEMO và 1 mô phỏng; sơ đồ không xác nhận triển khai production.', '- Không sửa ứng dụng; không viết đặc tả chi tiết, không tạo Actor hoặc quan hệ include/extend/generalization thiếu căn cứ.', '', '## Tài liệu', '', '- Diagram_Validation_Report.md: kết quả kiểm tra và các vấn đề cần xác minh.', '- UC_Diagram_Traceability.md: 162 UC → sơ đồ sở hữu → bằng chứng code.', '- Association_Traceability.md: nguồn và giới hạn từng đường tương tác, bao gồm V và provider.', '- Actor_Coverage_Index.md: toàn bộ phạm vi theo Actor; đối chiếu Matrix Giai đoạn 2.', '- data/diagram-manifest.json: danh mục sơ đồ, edge, điều kiện và nguồn dùng kiểm tra tự động.', '- Validation_Result.json và Render_Result.json: log kiểm tra dữ liệu và render thực tế.', '', '## Danh mục sơ đồ', '', '| Sơ đồ | Loại | Nhóm | UC | SVG | PNG |', '| --- | --- | --- | --- | --- | --- |'];
for (const diagram of diagrams) index.push('| ' + [linkTo(diagram), diagram.kind, diagram.groupId || (diagram.actorId || 'tổng thể'), diagram.ucIds.length, '[SVG](rendered/' + diagram.id + '.svg)', '[PNG](rendered/' + diagram.id + '.png)'].join(' | ') + ' |');
index.push('', '## Cách đọc đúng', '', 'Ellipse là UC thật, Actor nằm ngoài biên “Hệ thống quản lý nhà trọ”. Nhãn nhóm chỉ ở tiêu đề, không phải UC. Association là đường liền không hướng, không diễn tả thứ tự. Đường xanh có nhãn là V hạn chế. Khách chưa đăng nhập dùng A01; A04 không được chuyên biệt hóa thành hai security role. Provider E01–E05 là bên ngoài biên triển khai, kể cả khi được đặt trên máy nội bộ; chưa chứng minh được kết nối runtime.', '', 'Điều kiện ownership, trạng thái dữ liệu, permission, feature flag, MFA/step-up vẫn áp dụng dù không ghi dài trên mỗi đường. Không nối mọi UC vào Đăng nhập; đó là tiền điều kiện, không phải include. Không nối đề nghị→duyệt→thực thi bằng include/extend chỉ vì có thứ tự.', '', '## Tái tạo và kiểm tra', '', '\x60\x60\x60sh', 'node BA_Documentation/05_Use_Case_Diagrams/tools/generate.cjs', 'node BA_Documentation/05_Use_Case_Diagrams/tools/validate.cjs', 'JAVA_BIN=/opt/homebrew/opt/openjdk@17/bin/java PLANTUML_JAR=/tmp/ba-stage3-tooling/plantuml-1.2026.9.jar GRAPHVIZ_DOT=/Users/hoang/Rental_room_management/BA_Documentation/05_Use_Case_Diagrams/tools/graphviz-dot.cjs VIZJS_MODULE=/tmp/ba-stage3-tooling/graphviz/node_modules/@viz-js/viz node BA_Documentation/05_Use_Case_Diagrams/tools/render.cjs', '\x60\x60\x60', '', 'Nếu chưa có Graphviz native, cài bộ WASM ngoài dự án: npm install --prefix /tmp/ba-stage3-tooling/graphviz --no-audit --no-fund @viz-js/viz@3.17.0. Chạy validator sau khi render; visualInspection được đánh dấu bởi người kiểm tra sau khi xem ảnh, không tự xác nhận bằng script render.', '', 'Các script chỉ ghi trong thư mục tài liệu này. generate.cjs tái sinh .puml, manifest và bảng truy vết từ Catalog, không sửa Catalog. Render dùng PlantUML 1.2026.9 + Graphviz 13.1.2 qua @viz-js/viz 3.17.0 cục bộ, Java 17. Có thể thay bằng Graphviz dot native; không gửi sơ đồ lên dịch vụ công khai. Bản Smetana thử ban đầu có lệch điểm nối tại UC gắn stereotype nên không dùng cho bản bàn giao. JAR/runtime không đóng gói vào repository. Xem Render_Result.json để biết hash JAR, exit code và kích thước từng ảnh.', '');
write('README.md', index.join('\n'));
console.log(JSON.stringify({ diagrams: diagrams.length, modules: diagrams.filter(item => item.kind === 'module').length, staff: diagrams.filter(item => item.kind === 'actor').length, distinctUseCases: new Set(diagrams.filter(item => item.kind === 'module').flatMap(item => item.ucIds)).size }, null, 2));


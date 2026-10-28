# Admin Product Roadmap

> Ngày lập: 26/10/2026  
> Phạm vi: Admin Console của Rental Room Management.  
> Mục tiêu: biến các chức năng admin hiện có thành một trung tâm vận hành an toàn, có phân quyền chi tiết, xử lý được ticket/moderation/incident và cung cấp dữ liệu hỗ trợ mà không phá ownership của landlord.

## 1. Baseline hiện tại

Đã có trong source và đã được triển khai ở các sprint trước:

- Admin dashboard, capability-based permission, MFA/TOTP, recovery code và quản lý session.
- Account/landlord/property management, admin search, audit log và error envelope chuẩn hóa.
- Support ticket, internal note, reply, attachment scanner gate, saved view, assignment theo skill/capacity và notification delivery queue.
- Moderation queue, appeal/dispute nền tảng, policy version, evidence snapshot, bulk moderation và SLA escalation.
- Feature flags, admin team, permission simulator, finance reconciliation read-only và scheduled reports.
- Operations health, backup safety script, report storage guard và regression test cho các workflow quan trọng.

Baseline trên được đối chiếu source và tài liệu các sprint trước, không thay thế xác minh production. Các migration và external integrations chưa được xác minh trên production.

### Phân biệt phần đã có với phần mở rộng

| Nhóm | Tái sử dụng | Phần phát triển mới |
|---|---|---|
| Bảo mật | MFA, session revoke, MFA khi đổi admin/invite admin, chặn tự đổi quyền và bảo vệ super admin cuối cùng | Step-up có thời hạn cho hành động cụ thể, access review và quyền tạm thời |
| Operations | Health summary, incident acknowledge, retry dead letter, moderation escalation | Incident lifecycle đầy đủ, owner, snooze, resolve/reopen, runbook và lịch sử xử lý |
| Support | Ticket, notes/replies, templates, merge, CSAT, attachments, skill assignment | Hồ sơ hỗ trợ liên resource, business-hours SLA, pause/resume policy và escalation nhiều cấp |
| Moderation | Appeal, independent reviewer guard, history/evidence, bulk action, policy và báo cáo | Giao diện triage tốt hơn, QA sampling, enforcement có thời hạn và xử lý lỗi từng item rõ hơn |
| Search | Tìm account/property/room/ticket/tenant/invoice theo quyền | Mở rộng resource khi có nhu cầu, timeline liên kết và kiểm soát truy cập dữ liệu nhạy cảm |
| Governance | Team management, permission simulator, flag theo role/percentage | Approval cho thay đổi nhạy cảm, expiry, preview impact và scope bổ sung khi cần |
| Finance/report | Import sao kê, match có kiểm soát, maker-checker, lịch report/timezone, retry/signed link | Exception workbench, tiến độ xử lý, lịch sử truy cập/export và bàn giao ownership |

Danh sách chức năng trong từng sprint là phạm vi đích; phần đã có chỉ được bổ sung test hoặc cải tiến còn thiếu, không viết lại module.

### Phạm vi release đầu tiên

- Ưu tiên duy nhất: admin. Tạm hoãn tính năng mới cho landlord, tenant và marketplace; chỉ sửa contract liên quan khi workflow admin bắt buộc cần.
- Release admin tiếp theo gồm nền bảo mật cần thiết từ Sprint A, incident lifecycle của Sprint C và hồ sơ hỗ trợ/SLA của Sprint D.
- Giữ các hardening bắt buộc của Sprint J trong từng sprint; không dồn authorization, concurrency, migration safety hoặc manual QA đến cuối.
- Chưa cam kết lịch theo tuần khi chưa biết số người thực hiện và kết quả baseline; các thời lượng trong tài liệu là ước lượng phạm vi, không phải deadline.

## 2. Mục tiêu Admin Console

Admin Console cần trả lời được 5 câu hỏi:

1. **Có sự cố gì đang xảy ra?** — incident, queue, worker, SLA, failed delivery.
2. **Ai đang cần hỗ trợ?** — user/ticket/requester context nhưng PII được mask và có audit.
3. **Quyết định nào đang chờ xử lý?** — moderation, appeal, report, finance proposal, account action.
4. **Ai đã làm gì và vì sao?** — audit trail bất biến, version, reason, actor và evidence.
5. **Thao tác này có an toàn không?** — permission, step-up, maker-checker, idempotency và rollback/compensation.

## 3. Ưu tiên theo cấp độ

| Cấp | Nhóm | Kết quả |
|---|---|---|
| P0 | Admin security & release | Không cấp quyền rộng hơn khả năng audit/thu hồi |
| P1 | Operations command center | Admin xử lý được incident, queue và SLA hằng ngày |
| P1 | Support operations | Ticket có triage, SLA, escalation và lịch sử người dùng |
| P1 | Moderation operations | Appeal, decision quality và enforcement có kiểm soát |
| P1/P2 | Account/data support | Tra cứu toàn nền tảng nhưng giới hạn PII và không sửa tài chính trực tiếp |
| P2 | Finance governance | Đối soát, export, approval và báo cáo không phá sổ kế toán |
| P2 | Admin governance | Team, policy, feature flag, retention và access review |
| P2/P3 | Analytics | KPI vận hành, chất lượng dữ liệu và báo cáo định kỳ |

## 4. Sprint plan chi tiết

### Sprint A — Admin security & release gate

**Thời lượng:** 1 sprint  
**Mục tiêu:** củng cố nền tảng trước khi mở thêm quyền admin.

#### Backend

- Chuẩn hóa permission catalog: `view`, `manage`, `approve`, `export`, `reveal`, `impersonation` không được gộp tùy tiện.
- Thêm access review định kỳ: danh sách admin, role, team, last active, MFA status, quyền nhạy cảm và ngày review tiếp theo.
- Step-up authentication cho PII reveal, account suspension, admin-role change, bulk action và export nhạy cảm.
- Break-glass workflow có thời hạn, lý do bắt buộc, reviewer và tự động thu hồi.
- Kiểm tra access revocation ở request kế tiếp; không chỉ ẩn menu Flutter.
- Gắn audit cho mọi mutation admin còn thiếu và kiểm tra audit không thể update/delete từ API.

#### Flutter

- Màn Access Review, MFA status, session list và quyền nhạy cảm.
- Dialog step-up dùng chung, không tự lặp form reason ở từng màn.
- Hiển thị rõ `403`, `409 version conflict`, `step-up required`, `expired session`.

#### Acceptance criteria

- Admin bị thu hồi quyền không gọi được endpoint dù đang mở màn hình cũ.
- PII export/reveal luôn có reason, step-up và audit.
- Có E2E cho admin thường, super admin, staff, landlord và tenant gọi nhầm admin endpoint.

---

### Sprint B — Admin team và account lifecycle

**Thời lượng:** 1 sprint  
**Mục tiêu:** quản lý vòng đời admin mà không phải chỉnh database thủ công.

- Invite admin bằng token một lần, expiry, resend có rate limit và audit.
- Activation/deactivation, khóa tạm thời, thu hồi toàn bộ session và bắt buộc MFA.
- Gán admin vào team với preset permission; hỗ trợ custom permission có lý do.
- Không cho admin tự hạ quyền hoặc xóa người duy nhất có quyền recovery.
- Admin profile: last login, device/session, failed login, MFA/recovery status.
- Permission simulator theo actor, route, action, resource scope và expected decision.
- Export danh sách quyền phục vụ access review, nhưng mask email/PII không cần thiết.

#### Acceptance criteria

- Invite token không replay được và không hiển thị secret trong log.
- Deactivate có hiệu lực ngay với token/session đang tồn tại.
- Mọi thay đổi role/team có before/after, actor, reason và version.

---

### Sprint C — Operations command center

**Thời lượng:** 1–2 sprint  
**Mục tiêu:** admin xử lý vận hành từ một nơi duy nhất.

#### Dashboard cần có

- API/database readiness, worker last run, queue depth, dead letters, failed reports, backup age.
- Incident theo severity, status, owner, occurrences, first seen/last seen và SLA.
- Action items: moderation overdue, support overdue, payment exception, scanner failure, notification failure.
- Filter theo property/platform, severity, time range và owner.

#### Workflow

- Acknowledge, assign, snooze có thời hạn, resolve và reopen incident.
- Runbook link cho từng loại incident; ghi lại action và evidence.
- Retry job chỉ khi idempotent; hiển thị lý do không thể retry.
- Maintenance mode/read-only banner cho thao tác nguy hiểm; không cho sửa runtime secret từ UI.
- Alert deduplication và escalation nếu chưa acknowledge/resolve trong SLA.

#### Acceptance criteria

- Admin thấy được “việc cần làm” chứ không chỉ số liệu tổng hợp.
- Không thể đánh dấu resolve khi chưa có reason/evidence phù hợp.
- Worker thất bại tạo metric/incident có request/job identifier để điều tra.

---

### Sprint D — Support Center v2

**Thời lượng:** 2 sprint  
**Mục tiêu:** giảm thời gian phản hồi và không để ticket bị bỏ quên.

- Ticket triage: category, priority, requester type, sentiment/risk tag và duplicate detection.
- Hồ sơ xử lý liên resource: liên kết account, ticket, listing/report, incident và reconciliation exception; mỗi hồ sơ có owner, trạng thái, evidence và activity timeline. Không sao chép hoặc thay thế lifecycle của các resource gốc.
- SLA theo business hours, holiday calendar, first response và resolution deadline.
- Xác định trạng thái được tạm dừng SLA, timezone của team và cách tiếp tục đồng hồ khi user reply/reopen; SLA đã trôi qua không được xóa bằng reassignment.
- Escalation chain: agent -> team lead -> operations; tránh tự assign vòng lặp.
- Customer timeline read-only: ticket, notification, payment proof status, maintenance request, account events.
- Internal note bắt buộc cho escalation/reassignment/close; note không bao giờ gửi cho user.
- Canned response có version, approval và biến template an toàn.
- Merge ticket có preview, chống merge khác requester và giữ message/audit đầy đủ.
- CSAT theo ticket, agent/team, category; không dùng một điểm thấp để tự động phạt agent.

#### Acceptance criteria

- Ticket quá hạn tự xuất hiện trong queue escalation.
- User reply/reopen không làm mất assignment hoặc lịch sử SLA.
- PII, attachment và internal note được kiểm tra permission ở backend.

---

### Sprint E — Moderation v3

**Thời lượng:** 2 sprint  
**Mục tiêu:** quyết định moderation nhất quán, có kháng nghị và đo chất lượng.

- Appeal/dispute inbox: deadline, reason, evidence mới, assigned reviewer và conflict-of-interest check.
- Decision history dạng timeline: policy version, evidence snapshot, actor, reviewer, source và outcome.
- Bulk moderation có preview, per-item result, partial failure, idempotency và undo/compensation nếu policy cho phép.
- Enforcement ladder: warning, hide, restricted, suspend; mỗi mức có expiry/review date.
- Quality report: overturn rate, appeal rate, median handling time, disagreement rate và sample review.
- Policy test cases trước khi activate policy mới; không tự động activate policy nguy hiểm.
- Report/appeal liên kết với account/listing/review nhưng không cấp quyền sửa tùy ý dữ liệu gốc.

#### Acceptance criteria

- Người tạo quyết định không tự approve appeal của chính quyết định đó.
- Bulk action không xử lý item ngoài scope hoặc đã có version mới.
- Evidence snapshot vẫn xem được sau khi nội dung gốc thay đổi.

---

### Sprint F — Platform search và data support

**Thời lượng:** 1–2 sprint  
**Mục tiêu:** hỗ trợ điều tra nhanh mà không biến admin thành chủ sở hữu dữ liệu landlord.

#### Search scope

- Account/user, property, room, tenant, lease, ticket, invoice, payment event, listing, review và report.
- Search theo exact ID, email/phone đã mask, reference code, status và time range.
- Kết quả nhóm theo resource, permission-aware và có deep link tới màn chi tiết.

#### Data access boundary

- Mặc định read-only cho tenant/lease/invoice/payment; không sửa trực tiếp từ search.
- PII reveal cần capability riêng, reason, step-up và thời gian hiển thị ngắn.
- Không hiển thị refresh token, password hash, card data, CVC, scanner secret hoặc raw webhook secret.
- Customer context có mục đích và scope; audit ai đã mở dữ liệu gì.

#### Acceptance criteria

- Đổi ID trên URL/query không vượt permission hoặc property scope.
- Search có limit, pagination, timeout và không full-table scan không kiểm soát.
- Export dùng job queue, signed URL, retention và audit download.

---

### Sprint G — Finance governance cho admin

**Thời lượng:** 1 sprint  
**Mục tiêu:** admin nhìn được sức khỏe tài chính nhưng không phá ledger.

- Reconciliation dashboard: statement lines, unmatched, duplicate, needs review, aging và exceptions.
- Maker-checker cho match/unmatch/mark reviewed; người lập không tự duyệt.
- Read-only finance summary theo property/time range; mask account/reference nhạy cảm.
- Report run có snapshot version, owner, retention, retry và signed download.
- Audit export cho reconciliation, payment event và report access.
- Exception queue cho payment provider/webhook mismatch; có evidence và resolution note.

#### Không triển khai trong sprint này

- Admin sửa invoice/payment trực tiếp.
- Admin hoàn cọc hoặc refund tự động.
- Thay đổi bank account, payment provider secret hoặc ledger bằng UI.

#### Acceptance criteria

- Mọi reconciliation mutation có version, idempotency và audit nguyên tử.
- Không có endpoint “force match” bỏ qua rule unambiguous.
- Export không chứa secret hoặc dữ liệu thẻ.

---

### Sprint H — Governance, policy và feature rollout

**Thời lượng:** 1 sprint  
**Mục tiêu:** thay đổi chính sách và tính năng có kiểm soát.

- Feature flag theo environment, role/team, tenant/property scope, rollout percentage và expiry.
- Two-person approval cho flag bảo mật, rollout lớn hoặc policy moderation.
- Policy catalog: version, draft, review, active, retired; chỉ một active policy theo kind.
- Data retention policy cho audit, support attachment, report export, appeal evidence và notification delivery.
- Access review report, dormant admin detection và quyền hết hạn.
- Scheduled report ownership transfer khi admin rời team.
- Change log có diff trước/sau và link tới incident/ticket liên quan.

#### Acceptance criteria

- Flag/policy hết hạn không âm thầm giữ trạng thái nguy hiểm.
- Không activate policy/flag khi thiếu reviewer hoặc version conflict.
- Có rollback về version trước và audit đầy đủ.

---

### Sprint I — Admin analytics và operational intelligence

**Thời lượng:** 1–2 sprint  
**Mục tiêu:** admin đo được chất lượng vận hành thay vì chỉ xem danh sách.

- KPI: first response/resolution SLA, backlog, reopen rate, CSAT, appeal overturn rate, queue age.
- KPI reliability: API error rate, p95 latency, queue lag, failed jobs, backup age, scanner/notification success.
- KPI marketplace: listing reports, moderation turnaround, viewing conversion và abuse rate.
- Dashboard có date range/timezone, saved view, export async và data freshness timestamp.
- Data quality checks: missing property, duplicate payment reference, stale listing, orphan lease, invalid status transition.
- Không chạy aggregation nặng trực tiếp trên transaction path; dùng read model/materialized view khi cần.

#### Acceptance criteria

- Mỗi metric có định nghĩa, nguồn dữ liệu và thời điểm cập nhật.
- Hai admin xem cùng time range nhận kết quả nhất quán.
- Report chậm/failed không làm timeout request dashboard.

---

### Sprint J — Admin launch hardening

**Thời lượng:** 1 sprint  
**Mục tiêu:** chốt bản admin có thể vận hành production.

- E2E permission matrix cho mọi route admin.
- Concurrency test: two-admin update, stale version, duplicate submit, retry sau timeout.
- Security test: IDOR, PII masking, upload bypass, signed URL expiry, export authorization.
- Device/manual test cho mobile và desktop: responsive, large text, session change, logout khi đang mở form.
- Staging migration rehearsal, restore drill, worker recovery và external integration smoke test.
- Runbook: account lock, queue backlog, scanner down, notification outage, report storage down, DB failover.
- Release gate: test pass, migration checksum, backup verified, alert owner assigned, rollback plan documented.

## 5. Thứ tự triển khai khuyến nghị

1. Sprint A — Admin security & release gate.
2. Sprint C — Operations command center.
3. Sprint D — Support Center v2.
4. Sprint E — Moderation v3.
5. Sprint F — Platform search/data support.
6. Sprint B — Admin team/account lifecycle.
7. Sprint G — Finance governance.
8. Sprint H — Governance/rollout.
9. Sprint I — Analytics.
10. Sprint J — Launch hardening.

Sprint B có thể làm song song với Sprint C nếu cần quản lý nhiều admin sớm. Không nên làm Sprint I trước khi metric definition và data quality đã được chốt.

## 6. Backlog ticket ưu tiên nhất

### P0 — Tuần đầu

1. Permission catalog audit và access revocation E2E.
2. Step-up authentication cho PII/export/bulk/admin-role change.
3. Audit gap scan cho toàn bộ admin mutation.
4. Admin operations dashboard: queue, dead letter, worker, incident, backup age.

### P1 — Sau P0

5. Support business-hours SLA và escalation chain.
6. Customer timeline read-only với PII masking.
7. Appeal/dispute inbox và conflict-of-interest guard.
8. Moderation enforcement ladder và quality report.
9. Platform search permission-aware và async export.
10. Admin invite/deactivate/team assignment.

### P2 — Sau khi vận hành ổn định

11. Finance exception queue và maker-checker dashboard.
12. Policy/feature flag two-person approval và expiry.
13. Data retention/access review.
14. KPI dashboard và data quality checks.

### Ticket mẫu cho release admin đầu tiên

| Ticket | Deliverable | Phụ thuộc | Tiêu chí nghiệm thu trọng tâm |
|---|---|---|---|
| ADM-01 | Ma trận route/capability và test bổ sung | Baseline source hiện tại | Request trực tiếp bị từ chối sau khi quyền bị thu hồi; không chỉ ẩn nút |
| ADM-02 | Step-up cho danh mục hành động nhạy cảm | ADM-01 | Grant ràng buộc session/action, hết hạn và không dùng cho hành động khác |
| ADM-03 | Incident assign/snooze/resolve/reopen và UI | ADM-01 | Hai admin không ghi đè; alert lặp không tạo incident trùng; snooze không xóa lỗi |
| ADM-04 | Support case + customer activity timeline | ADM-01 | Timeline chỉ trả resource/trường được phép; internal note không xuất hiện ở user API |
| ADM-05 | Business calendar và SLA clock | Policy SLA được xác nhận | Test ngoài giờ, ngày nghỉ, pause/resume/reopen, timezone và DST nếu timezone hỗ trợ |
| ADM-06 | Escalation worker + assignment inbox | ADM-04, ADM-05 | Retry không tạo escalation/thông báo trùng; worker có metric và audit |
| ADM-07 | Permission/concurrency/device QA và runbook release | ADM-02 đến ADM-06 | Test trên DB cô lập; staging rehearsal, quyền khác nhau và external provider smoke |

Thiết kế API/schema cụ thể nằm trong ticket khi bắt đầu code. Ưu tiên tái sử dụng incident, ticket, audit, notification delivery và reconciliation proposal đang có; chỉ thêm bảng khi trạng thái mới thực sự cần persist.

## 7. Quyền admin đề xuất

Đây là đề xuất phân tách capability cho tính năng mới, không phải danh sách permission đã tồn tại. Khi triển khai phải map với catalog/preset hiện hành, giữ tương thích hoặc có migration rõ ràng; không đổi tên permission cũ âm thầm.

| Permission | Mục đích | Mặc định |
|---|---|---|
| `admin.operations.view` | Xem health, queue, incident | Operations/support |
| `admin.operations.manage` | Acknowledge, assign, retry an toàn | Operations lead |
| `admin.support.read` | Xem support/customer context | Support |
| `admin.support.manage` | Reply, assign, escalate, resolve | Support lead |
| `admin.moderation.view` | Xem queue/history/evidence | Moderator |
| `admin.moderation.decide` | Ra quyết định moderation | Moderator lead |
| `admin.moderation.approve` | Duyệt appeal/bulk/policy | Senior moderator |
| `admin.finance.view` | Xem summary/reconciliation | Analyst |
| `admin.finance.reconcile` | Tạo proposal reconciliation | Finance operator |
| `admin.finance.approve` | Duyệt proposal của người khác | Finance lead |
| `admin.pii.reveal` | Reveal PII có reason/step-up | Restricted |
| `admin.export.create` | Tạo export async | Theo team |
| `admin.admins.manage` | Invite, deactivate, team/role | Super admin |
| `admin.policies.manage` | Policy/flag/retention | Super admin |

Không cấp `admin.*` wildcard cho user production; preset chỉ là shortcut để tạo permission cụ thể.

## 8. Definition of Done cho mọi admin ticket

- Backend DTO validation, permission server-side, resource scope và error code ổn định.
- Với approval: maker khác checker; kiểm tra quyền của cả hai tại thời điểm thực thi, request còn hạn và target version chưa thay đổi; chống approve/execute lặp. Ưu tiên áp dụng vào workflow hiện hữu trước khi dựng approval engine dùng chung.
- Mutation có reason, version/lock/idempotency khi cần; audit nằm trong cùng transaction.
- Có masking PII, attachment URL authorization và export retention.
- Flutter có loading, empty, retry, conflict, stale-session và permission state.
- Có unit test, E2E HTTP, widget test và concurrency test phù hợp.
- Có manual verification với ít nhất hai preset quyền trên mobile và desktop.
- Có migration/backfill plan, backup/restore verification và rollback plan.
- Cập nhật `PROJECT_STATUS.md`, `UPDATE_LOG.md` và runbook sau khi thực sự verify.

## 9. Quyết định cần xác nhận theo từng ticket

- Mục tiêu first response/resolution, timezone, giờ làm việc và trạng thái pause SLA.
- Ai được duyệt thay đổi quyền, sanctions, export nhạy cảm và feature rollout; ai xử lý khi không có reviewer.
- Những trường PII nào mỗi team được xem, mục đích và thời gian hiển thị; thời hạn lưu evidence/export phải do người phụ trách quyết định.
- Sự cố nào cần escalation ngay, ai nhận cảnh báo và tiêu chí được phép resolve.
- Có thực sự cần quyền tạm thời/break-glass hay không; mặc định chưa mở impersonation.

## 10. Không nên làm trong roadmap admin này

- Không cho admin CRUD toàn quyền room, tenant, lease, invoice hoặc payment.
- Không có impersonation không giới hạn; nếu cần phải là workflow có approval, expiry và audit.
- Không cho xem raw database, secret, password hash, token, card data hoặc raw webhook payload nhạy cảm.
- Không tự động khóa tài khoản/xóa listing chỉ dựa trên số lượng report.
- Không để AI tự duyệt moderation, tự hoàn tiền hoặc tự thay đổi permission.
- Không migrate working/production DB nếu chưa có rehearsal, backup và người chịu trách nhiệm rollback.

# Roadmap phát triển Rental Room Management

> Ngày lập: 26/10/2026  
> Phạm vi: Flutter app, NestJS API, PostgreSQL/Prisma và các worker vận hành.  
> Mục tiêu: đưa sản phẩm từ trạng thái đã có nhiều module sang một hệ thống quản lý cho thuê có thể vận hành thật, đo lường được và mở rộng an toàn.

> Cập nhật ưu tiên ngày 26/10/2026: tập trung phát triển admin trước theo `docs/ADMIN_PRODUCT_ROADMAP_2026-10-26.md`. Các giai đoạn landlord/tenant/marketplace trong tài liệu này chuyển thành backlog sau; không dùng lịch tuần dưới đây làm cam kết triển khai hiện tại.

## 1. Định hướng sản phẩm

Sản phẩm nên được phát triển theo vòng đời chính:

`Khu trọ -> Phòng -> Hợp đồng -> Người thuê -> Hóa đơn -> Thanh toán -> Bảo trì -> Trả phòng -> Báo cáo`.

Ba nguyên tắc cần giữ trong mọi sprint:

1. **Dữ liệu tài chính không bị mất lịch sử:** không xóa cứng invoice, payment, deposit hoặc khoản nợ đã phát sinh.
2. **Backend là nơi quyết định quyền:** Flutter chỉ hỗ trợ UX; mọi ownership, property scope, permission, idempotency và audit phải kiểm tra ở API.
3. **Mọi flow quan trọng phải có trạng thái và bằng chứng:** loading, empty, retry, conflict, audit, test và manual verification.

## 2. Ưu tiên tổng thể

| Mức | Nhóm | Mục tiêu |
|---|---|---|
| P0 | Production readiness | Có thể deploy an toàn, khôi phục được và biết hệ thống đang lỗi ở đâu |
| P1 | Rental lifecycle | Hoàn chỉnh từ bắt đầu hợp đồng đến trả phòng/quyết toán |
| P1 | Billing & collections | Tính đúng tiền, theo dõi công nợ và đối soát không trùng |
| P1 | Tenant self-service | Người thuê tự gửi yêu cầu, gia hạn, trả phòng và theo dõi trạng thái |
| P1/P2 | Staff operations | Nhân viên chỉ thấy đúng khu trọ và xử lý công việc theo SLA |
| P2 | Admin/support quality | Hỗ trợ, moderation, governance và báo cáo vận hành ở mức production |
| P2/P3 | Marketplace | Tăng số lead và chuyển đổi từ tìm phòng đến ký hợp đồng |
| P3 | Integrations & intelligence | Push/Zalo, automation, analytics nâng cao và AI có kiểm soát |

## 3. Roadmap theo giai đoạn

### Giai đoạn 0 — Production readiness

**Thời lượng đề xuất:** 1–2 tuần  
**Mục tiêu:** không mở rộng nghiệp vụ mới trước khi hệ thống có thể release an toàn.

#### Backend/infrastructure

- Chạy migration mới trên staging từ backup; kiểm tra checksum, thời gian chạy và rollback plan.
- Thiết lập secret production: JWT/session, MFA encryption, upload scanner, report storage, notification provider, backup off-site.
- Hoàn chỉnh worker supervision: billing, reminders, notifications, report export, backup; mỗi job có retry, idempotency và dead-letter.
- Thêm health/readiness checks cho database, object storage, scanner, notification provider và queue.
- Gắn `requestId`, structured logs, error rate, latency p95, queue depth, failed jobs và backup age vào monitoring.
- Kiểm tra rate limit, CORS, HTTPS, cookie/token policy, upload size/type và redaction dữ liệu cá nhân.

#### Flutter/release

- Chạy manual smoke flow trên simulator/device: login, refresh, logout, property, room, lease, invoice, payment proof, maintenance, admin.
- Xử lý các lỗi dashboard/navigation còn lại; `flutter analyze` không còn warning mới do feature đang phát triển.
- Tách config dev/staging/production; không hardcode API URL, demo gateway hoặc credential.
- Chuẩn bị crash reporting, app version, forced upgrade và release checklist.

#### Definition of Done

- Deploy staging từ commit sạch; migration chạy trên DB snapshot.
- Có restore drill thành công và có người nhận alert khi backup/worker thất bại.
- Smoke test quan trọng pass trên backend thật và thiết bị/simulator.

---

### Giai đoạn 1 — Hoàn chỉnh vòng đời thuê

**Thời lượng đề xuất:** 2 sprint  
**Ưu tiên:** P1.

#### 1. Trả phòng và quyết toán

- Wizard cho ngày trả, chỉ số điện/nước cuối, tiền thuê lẻ ngày, hư hỏng, phí vệ sinh và ghi chú.
- Preview quyết toán gồm: tiền phải thu, tiền cọc, khấu trừ, số hoàn và số còn nợ.
- Biên bản trả phòng độc lập với biên bản nhận phòng; hỗ trợ ảnh/tài sản làm bằng chứng.
- Chốt quyết toán bằng `version` + `idempotencyKey`; không tạo trùng invoice/payment/deposit transaction khi bấm lại.
- Ghi nhận khoản hoàn/khấu trừ bằng transaction riêng; không coi thao tác xác nhận là tiền đã chuyển.
- Sau khi kết thúc lease, phòng chuyển sang trạng thái sẵn sàng hoặc cần bảo trì theo kết quả kiểm tra.

#### 2. Gia hạn và kết thúc hợp đồng

- Tenant gửi yêu cầu gia hạn/trả phòng; landlord/staff duyệt hoặc từ chối có lý do.
- Kiểm tra overlap thời gian lease và giữ lịch sử các phiên bản hợp đồng.
- Hiển thị deadline, trạng thái chờ duyệt và thông báo hai chiều.

#### Acceptance criteria

- Không thể đóng lease sai property/tenant hoặc có overlap.
- Quyết toán có thể xem lại sau khi đóng và không sửa ngầm dữ liệu cũ.
- Test transaction, concurrency, permission, idempotency và E2E trên DB sạch.

---

### Giai đoạn 2 — Billing, công nợ và đối soát

**Thời lượng đề xuất:** 2 sprint  
**Ưu tiên:** P1.

#### 1. Invoice engine

- Invoice line items: tiền phòng, điện, nước, dịch vụ, giảm giá, phạt, phí một lần.
- Versioned tariff/service charge theo property hoặc room; invoice lưu snapshot đơn giá tại thời điểm phát hành.
- Preview trước khi phát hành; công thức tiền lẻ ngày dùng một chính sách thống nhất và có test biên.
- Điều chỉnh invoice bằng credit/debit adjustment, không sửa trực tiếp invoice đã phát hành.
- Bulk invoice có preflight, giới hạn lô, tiến độ và retry an toàn.

#### 2. Collections

- Aging buckets: chưa đến hạn, 1–7 ngày, 8–30 ngày, quá hạn trên 30 ngày.
- Nhắc nợ theo policy, chống gửi trùng và có opt-out phù hợp.
- Payment webhook/provider thật có signature verification, replay protection và idempotency.
- Dashboard collection rate, outstanding, aging, failed payments và reconciliation exceptions.

#### Acceptance criteria

- Tất cả số tiền dùng integer minor units, không tính bằng floating point.
- Cùng một event/payment provider không thể ghi nhận hai lần.
- Có test invoice calculation, timezone, rounding, partial payment, refund/adjustment và đối soát.

---

### Giai đoạn 3 — Tenant self-service

**Thời lượng đề xuất:** 2 sprint  
**Ưu tiên:** P1.

- Tenant xem hợp đồng, thành viên cư trú, lịch thanh toán, tiền cọc và các mốc quan trọng.
- Gửi yêu cầu gia hạn, trả phòng, chuyển phòng hoặc thay đổi thông tin; landlord/staff xử lý theo workflow.
- Quản lý co-occupants: thêm/xóa, vai trò đại diện, quyền xem invoice và yêu cầu.
- Chuyển phòng có hiệu lực từ ngày cụ thể, không xóa lịch sử room/lease cũ và kiểm tra sức chứa.
- Maintenance nâng cao: category, priority, attachment, assignment, SLA, chi phí dự kiến, nghiệm thu.
- Notification center trong app; email/push/Zalo là các channel có preference và delivery status.
- Deep links từ notification tới invoice, ticket, request và approval.

#### Acceptance criteria

- Tenant không đọc được dữ liệu của property/lease khác bằng cách đổi ID.
- Request có trạng thái, người xử lý, SLA, audit và conflict handling.
- Upload chạy được với file thật, scanner thật hoặc provider staging tương đương.

---

### Giai đoạn 4 — Staff operations và property scope

**Thời lượng đề xuất:** 1–2 sprint  
**Ưu tiên:** P1/P2.

- Gán staff vào một hoặc nhiều property với ngày hiệu lực và trạng thái active.
- Tách permission hành động khỏi data scope; kiểm tra scope ở list, detail, report, upload và mutation.
- Staff dashboard: phòng trống, công nợ, maintenance, move-in/move-out và việc quá hạn.
- Assignment queue cho maintenance, support và inspection; có workload/capacity.
- Bulk operations có preview, giới hạn batch, audit và rollback/compensation khi một item lỗi.
- Handover khi staff nghỉ hoặc bị thu hồi quyền; không làm mất ownership/audit.

#### Acceptance criteria

- Staff gọi trực tiếp ID ngoài property scope luôn bị từ chối ở backend.
- Thu hồi assignment có hiệu lực ở request kế tiếp.
- Có test matrix owner/admin/staff/tenant và cross-property access.

---

### Giai đoạn 5 — Admin, support và governance production

**Thời lượng đề xuất:** 2 sprint  
**Ưu tiên:** P2.

- Admin search hợp nhất account, property, room, tenant, ticket, invoice với masking PII.
- Support template/canned response, labels, merge ticket, CSAT và saved views hoàn chỉnh.
- SLA escalation theo business hours, holiday calendar và escalation chain.
- Moderation policy versioning, appeal/dispute, evidence snapshot, bulk action và quality reports.
- Feature flags có environment/tenant scope, rollout percentage, expiry và kill switch.
- Admin team membership, permission simulator và export audit có approval/reason.
- Finance reconciliation chỉ read-only cho analyst; thao tác nhạy cảm dùng maker-checker.
- Scheduled reports có ownership, retention, signed links, retry và audit download.

#### Acceptance criteria

- Không có admin endpoint mutation mới mà thiếu capability, audit và reason khi cần.
- PII được mask trong search, logs, export và support view.
- Các queue/report có metric, retry và alert khi quá SLA.

---

### Giai đoạn 6 — Marketplace và tăng chuyển đổi

**Thời lượng đề xuất:** 2 sprint  
**Ưu tiên:** P2/P3.

- Listing lifecycle: draft, pending review, published, paused, rented, expired, rejected.
- Đồng bộ số phòng còn trống từ room/lease; không hiển thị listing đã hết phòng.
- Search/filter/sort theo vị trí, giá, tiện ích, ngày trống và độ tin cậy dữ liệu.
- Saved search/favorites có notification preference, chống gửi trùng và unsubscribe.
- Viewing appointment: tenant đặt lịch, landlord xác nhận, đổi lịch, hủy và nhắc lịch.
- Anti-abuse: rate limit contact, report listing, block spam và audit moderation.
- Funnel analytics: view -> favorite -> contact -> viewing -> application -> lease.

#### Acceptance criteria

- Trạng thái listing thay đổi đúng theo lease/room và không có listing ma.
- Lead có consent, trạng thái xử lý và không lộ contact ngoài quyền.
- Có thử nghiệm thực tế với nhóm landlord/tenant nhỏ trước khi mở rộng.

---

### Giai đoạn 7 — Tích hợp và intelligence

**Thời lượng đề xuất:** sau khi P1 ổn định  
**Ưu tiên:** P3.

- Push notification thật, email provider và Zalo/ZNS qua adapter có sandbox/production separation.
- Outbox/event processing cho invoice, payment, maintenance, notification và audit.
- Public/internal webhook management: signing secret, replay, delivery log, retry và revoke.
- Data warehouse hoặc read model cho analytics, không chạy truy vấn nặng trên transaction tables.
- Forecast occupancy, cash collection và maintenance cost; luôn hiển thị nguồn dữ liệu và thời gian cập nhật.
- Chatbot/RAG chỉ trả lời dữ liệu đã được phân quyền; không cho AI tự quyết định tiền, quyền hoặc moderation.

## 4. Lịch triển khai đề xuất

| Tuần | Trọng tâm | Kết quả |
|---|---|---|
| 1–2 | Production readiness | Staging release, secrets, monitoring, restore drill, smoke test |
| 3–4 | Move-out + settlement | Quyết toán cọc/công nợ và đóng lease an toàn |
| 5–6 | Billing engine | Line items, tariff snapshot, adjustment, aging |
| 7–8 | Tenant requests | Gia hạn, trả phòng, co-occupant, chuyển phòng |
| 9–10 | Maintenance/staff scope | Assignment, SLA, property-scoped access |
| 11–12 | Admin/support quality | Search, escalation, policy, governance hardening |
| 13–14 | Marketplace | Listing lifecycle, viewing, funnel metrics |
| 15+ | Integrations | Push/Zalo, outbox, analytics và AI có guardrail |

Mỗi sprint nên kết thúc bằng một vertical slice chạy được từ Flutter đến API/database, thay vì hoàn thành riêng từng lớp.

## 5. Backlog ticket ưu tiên

### P0 — Làm trước

1. Staging migration rehearsal và restore drill.
2. Production secret/config matrix.
3. Worker health, queue metrics và alerting.
4. Flutter/backend smoke suite trên thiết bị và DB test sạch.

### P1 — Tạo giá trị trực tiếp

5. Move-out settlement preview và commit.
6. Deposit transaction ledger và refund/forfeit workflow.
7. Invoice line items và versioned service tariffs.
8. Aging report và reminder policy.
9. Tenant extension/move-out request.
10. Co-occupant và room transfer.
11. Maintenance assignment/SLA.
12. Staff property scope.

### P2 — Mở rộng vận hành

13. Admin global search.
14. Support escalation và CSAT analytics.
15. Moderation quality report.
16. Listing lifecycle và availability sync.
17. Viewing appointment.

### P3 — Tối ưu quy mô

18. Push/Zalo provider thật.
19. Outbox/webhook platform.
20. Analytics read model.
21. Forecasting và AI assistant có permission guardrail.

## 6. Quyết định nghiệp vụ cần chốt trước khi code P1

- Tiền thuê lẻ ngày tính theo số ngày thực của tháng hay quy ước cố định.
- Ngày vào/ngày ra có tính đủ ngày hay không; cách làm tròn tiền.
- Tiền cọc có được bù trừ vào công nợ không; ai duyệt khấu trừ/hoàn cọc.
- Có cho đóng lease khi còn nợ không; khoản nợ đi vào collection như thế nào.
- Một lease nhiều người: ai là đại diện, ai xem invoice và ai được gửi request.
- Chuyển phòng tính lại giá/đặt cọc từ ngày nào và xử lý invoice đang mở ra sao.
- SLA dùng giờ lịch hay giờ làm việc; lịch ngày nghỉ lấy từ đâu.

## 7. Definition of Done dùng cho mọi ticket

- Có API DTO, validation, authorization/ownership/property scope và error code ổn định.
- Có transaction/idempotency/version check cho mutation có rủi ro lặp hoặc tranh chấp.
- Có Flutter loading, empty, retry, validation, conflict và offline/error state phù hợp.
- Có audit cho thao tác tài chính, quyền, moderation, support và thay đổi trạng thái quan trọng.
- Có unit test, repository/widget test và E2E cho permission, ownership, transaction và idempotency.
- Có manual verification cho upload, notification, PDF, payment provider và device-specific behavior.
- Cập nhật `PROJECT_STATUS.md`, `UPDATE_LOG.md` và runbook sau khi verify; không đánh dấu hoàn thành chỉ vì source compile.

## 8. Không nên triển khai ngay

- Không mở rộng chatbot/AI trước khi billing, lease lifecycle và maintenance ổn định.
- Không thêm nhiều payment provider trước khi idempotency, reconciliation và refund ledger hoàn chỉnh.
- Không cho admin sửa trực tiếp invoice/payment/lease ngoài workflow có audit và maker-checker.
- Không bật Zalo/ZNS production bằng mock provider.
- Không chạy migration trên working/production DB khi chưa có backup, rehearsal và rollback plan.

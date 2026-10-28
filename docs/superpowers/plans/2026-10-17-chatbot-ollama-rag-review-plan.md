# Chatbot Ollama + RAG Implementation Plan

**Trạng thái:** ĐỀ XUẤT CHỜ DUYỆT. Việc tạo tài liệu này không phải phê duyệt triển khai.
**Vai trò hiện tại:** Roadmap V1 mở rộng. Đợt triển khai đầu tiên dùng bản chốt `2026-10-17-chatbot-rag-mvp.md` cùng thư mục; không triển khai toàn bộ phạm vi tài liệu này cho MVP.
**Ngày:** 17/10/2026, múi giờ Asia/Ho_Chi_Minh.
**Goal:** Hoàn thiện chatbot tiếng Việt trong ứng dụng quản lý trọ, có RAG từ tài liệu đã duyệt, trích nguồn, dữ liệu nghiệp vụ trực tiếp và phân quyền.
**Architecture:** Flutter gọi NestJS bằng JWT. NestJS điều phối Ollama, truy xuất tri thức trong phạm vi được phép và gọi các service nghiệp vụ theo danh sách cho phép. Không cho model truy cập database, filesystem hay mạng tùy ý.
**Tech Stack:** Flutter/Riverpod/Dio/GoRouter hiện tại; NestJS/Prisma/PostgreSQL hiện tại; đề xuất thêm Ollama và pgvector sau bước kiểm tra tương thích.
**Spec:** Đặc tả đề xuất nằm trong các mục 1–12 của chính tài liệu này. Sau khi người dùng duyệt mới chốt task triển khai và viết mã.

## 1. Quyết định đề xuất để duyệt

1. Có RAG ngay trong phiên bản đầu, không hoãn sang giai đoạn khác.
2. Pilot cho landlord trước; bản hoàn thiện V1 bổ sung tenant và staff sau khi vượt kiểm thử phân quyền. Admin chỉ quản lý tài liệu hướng dẫn dùng chung, không mặc nhiên được đọc hội thoại hoặc dữ liệu riêng của chủ trọ.
3. Chatbot chỉ đọc nghiệp vụ. Việc quản lý tài liệu là thao tác rõ ràng của người dùng qua màn hình quản lý, không do chatbot tự quyết định.
4. Tài liệu ban đầu là Markdown/TXT và trình soạn văn bản trong ứng dụng; không hỗ trợ PDF/Word/OCR trong V1. Đây là giới hạn định dạng, không phải bỏ RAG.
5. Mình soạn hướng dẫn và FAQ từ luồng code thực tế; người dùng xác nhận quy định riêng. Chỉ tài liệu đã duyệt và index thành công mới được tìm kiếm.
6. Kho vector dùng PostgreSQL + pgvector để tránh vận hành thêm database; kiểm tra khả năng cài extension, kiểu vector và migration trong giai đoạn 0 trước khi chốt.
7. Model trả lời ứng viên: Qwen2.5 7B quantized; đối chứng Llama 3.1 8B. Model embedding ứng viên: embeddinggemma. Tên tag/digest và chất lượng tiếng Việt phải xác minh bằng benchmark, không coi là lựa chọn đã chứng minh.
8. Chạy local trên Mac ở giai đoạn phát triển/pilot. Máy chủ production và ngân sách phần cứng là quyết định riêng trước khi phát hành công khai.
9. V1 trả kết quả hoàn chỉnh, chưa streaming; timeout riêng cho chat, hàng đợi có giới hạn.
10. Không fine-tune, không LangChain/LlamaIndex hoặc backend Python riêng trong thiết kế ban đầu; chỉ bổ sung nếu benchmark cho thấy nhu cầu cụ thể.

## 2. Căn cứ code đã khảo sát

- Frontend: `/Users/hoang/Rental_room_management`, Flutter, Riverpod, Dio, GoRouter.
- Backend: `backend`, NestJS, Prisma và PostgreSQL theo cấu hình dự án.
- Có modules Rooms, Billing, Reports, Leases, Maintenance và TenantPortal để đối chiếu nghiệp vụ.
- `src/common/current-user.decorator.ts` có `AuthUser` và `landlordScopeId()`; tenant phải dùng ánh xạ tài khoản tenant, không dùng helper landlord như một quyền truy cập tenant.
- `src/common/roles.guard.ts` và `src/common/permissions.constants.ts` kiểm soát quyền staff; gọi service nội bộ không tự chạy lại guard của controller nghiệp vụ.
- `src/dashboard/dashboard.module.ts` chưa export service; module cần export đúng service khi tích hợp, không nhân bản provider một cách tùy ý.
- Flutter có `sessionIdentityProvider`, `sessionDioProvider` và `selectedPropertyProvider`; dùng lại nhưng cần hủy request/loại bỏ state khi phiên hoặc phạm vi thay đổi.
- `lib/core/network/api_client.dart` đang có receive timeout 15 giây. Không tăng timeout toàn ứng dụng chỉ để phục vụ AI.
- Chưa thấy chatbot/Ollama/embedding/pgvector trong vùng source/schema đã tìm kiếm. Đây không phải xác nhận runtime của toàn hệ thống.
- Worktree có nhiều thay đổi sẵn. Triển khai phải giữ nguyên thay đổi không thuộc task, kiểm tra lại baseline trước khi sửa từng repo.

## 3. Use cases và phạm vi quyền

| Vai trò | Hỏi tài liệu | Tra cứu nghiệp vụ | Quản lý tri thức |
| --- | --- | --- | --- |
| Landlord | Hướng dẫn cho chủ trọ và tài liệu của mình | Phòng, hóa đơn, báo cáo, hợp đồng, bảo trì thuộc phạm vi của mình | Soạn, nhập, duyệt, xuất bản, thu hồi tài liệu riêng |
| Tenant | Hướng dẫn tenant và nội quy được chia sẻ cho khu trọ đang có quyền | Hóa đơn, hợp đồng dạng dữ liệu và yêu cầu bảo trì của chính mình | Không |
| Staff | Hướng dẫn phù hợp quyền và tài liệu đã được chia sẻ | Chỉ tool tương ứng quyền hiện tại | Không trong V1 |
| Admin | Hướng dẫn quản trị và tài liệu dùng chung | Không có tool truy cập nghiệp vụ xuyên landlord trong V1 | Xuất bản tài liệu hướng dẫn dùng chung |

Ví dụ: nội quy vật nuôi dùng RAG; công nợ phòng 101 dùng Billing; câu hỏi vừa về số dư vừa về chính sách dùng cả hai và nêu rõ nguồn từng phần. Điều khoản hợp đồng chỉ được trích dẫn nếu thực sự có tài liệu đã duyệt; không suy ra điều khoản từ vài trường dữ liệu của lease.

Giới hạn V1: không chatbot tạo/sửa/xóa hóa đơn, ghi nhận tiền, duyệt chứng từ, gửi thông báo, sửa hợp đồng; không upload hợp đồng riêng tư để RAG trong đợt đầu; không OCR/ảnh/giọng nói, tìm web hoặc multi-agent.

## 4. Kiến trúc và luồng xử lý

```text
Flutter Chat / Knowledge Management
               |
        NestJS JWT + quyền hiện tại
               |
        Chat Orchestrator
          /             \
  Knowledge search    Business tools
  + ACL + phiên bản   + validate + quyền
          |                |
  PostgreSQL/vector    Services hiện có
          \                /
         Dữ liệu rút gọn có nguồn
                   |
             Ollama trả lời
                   |
     Kiểm tra output/citations + lưu lịch sử
```

- Ollama adapter có hai thao tác riêng: tạo embedding và sinh câu trả lời/tool request. URL/model do cấu hình server quyết định, không nhận từ client.
- Orchestrator nhận câu hỏi và ngữ cảnh do server dựng. Model chỉ được thấy tool mà tài khoản có khả năng dùng; executor vẫn kiểm tra quyền lại.
- Retrieval là một tool được kiểm soát, có thể phối hợp với tool nghiệp vụ. Có giới hạn tổng số lần gọi và thời gian xử lý toàn lượt.
- Nếu model chọn tool/JSON không ổn định: chuyển sang router intent có schema và tập giá trị hữu hạn; không mở quyền để bù chất lượng model.
- Trước khi lưu/trả lời, kiểm tra lại quyền đối với nguồn đã dùng. Nếu quyền bị thu hồi trong lúc model chạy, bỏ nội dung phụ thuộc nguồn đó và yêu cầu hỏi lại.
- Chỉ lưu các nguồn thực sự được dùng, không coi văn bản tự khai báo của model là citation hợp lệ.

## 5. Xây bộ tài liệu ban đầu

### 5.1. Bộ tài liệu dự kiến

12 tài liệu hướng dẫn/FAQ: tổng quan và vai trò; khu trọ; phòng; người thuê; hợp đồng; chỉ số điện nước; hóa đơn; thanh toán/chứng từ; bảo trì; báo cáo; tenant portal; FAQ theo vai trò.

3 mẫu cần người dùng điền/xác nhận: nội quy sinh hoạt; bảng điện/nước/phí; quy trình chuyển vào/trả phòng. Mẫu chưa điền phải ở trạng thái draft và không được index làm nguồn trả lời.

### 5.2. Quy trình soạn

1. Đọc screen, route, API, service và test của từng luồng.
2. Ghi lại tính năng thực sự có trong source; với luồng chưa kiểm chứng runtime phải đánh dấu cho reviewer, không quảng bá là đã hoạt động.
3. Soạn tiếng Việt theo cấu trúc: đối tượng, điều kiện, thao tác, kết quả, lỗi thường gặp và giới hạn.
4. Dùng dữ liệu giả được gắn nhãn; không đưa thông tin người thuê thật vào tài liệu mẫu.
5. Người dùng duyệt nội dung trong màn hình quản lý hoặc quy trình duyệt seed documents; lưu người duyệt và thời điểm duyệt.
6. Preview các đoạn index và chạy câu hỏi thử trước khi xuất bản.

### 5.3. Metadata bắt buộc

Document ID, title, loại tài liệu, owner landlord hoặc phạm vi hướng dẫn dùng chung, property scope nếu có, audience roles, required permissions nếu có, ngôn ngữ, phiên bản, trạng thái duyệt, người duyệt, ngày hiệu lực, ngày cập nhật, hash nội dung và nguồn soạn.

Không dùng một cờ public mơ hồ. Tài liệu dùng chung được xác định riêng và vẫn lọc theo audience. Nội quy riêng luôn có owner; tenant không được đọc chỉ vì tài liệu có role tenant mà thiếu điều kiện khu trọ/quan hệ thuê.

## 6. Pipeline RAG và vòng đời tài liệu

### 6.1. Nhập và chia đoạn

- V1 nhận Markdown/TXT UTF-8 hoặc văn bản soạn trực tiếp. Giới hạn khởi điểm 2 MB/file, 200.000 ký tự sau chuẩn hóa; từ chối định dạng khác, binary và nội dung rỗng.
- Không chạy HTML/script hoặc tự tải URL trong tài liệu. Không fetch ảnh/link để tránh truy cập mạng không kiểm soát.
- Chia theo tiêu đề và đoạn; thử 300–600 token/chunk, overlap 50–80 token, tinh chỉnh qua bộ eval. Dùng token counter phù hợp hoặc chiến lược đo bảo thủ, không coi số ký tự là số token.
- Giữ document/revision ID, heading, thứ tự đoạn và offset; không tạo số trang giả cho Markdown.
- Chunk không vượt ranh giới tài liệu, phiên bản hoặc phạm vi quyền.

### 6.2. Lưu trữ, duyệt và index

- Tách trạng thái biên tập `DRAFT/APPROVED/REVOKED` khỏi trạng thái index `PENDING/PROCESSING/READY/FAILED`.
- Chỉ revision APPROVED + READY + có hiệu lực được phục vụ.
- Sửa tài liệu tạo revision mới. Bản đã xuất bản còn hoạt động cho tới khi bản mới duyệt và index hoàn tất; đổi con trỏ active revision bằng transaction ngắn.
- Thu hồi/xóa làm tài liệu không còn truy xuất được ngay. Xóa chunks/embeddings và xử lý references trong lịch sử bằng job có thể retry.
- Dùng bảng job và worker trong NestJS, có lock/lease, retry tối đa 3 lần với backoff, idempotency theo revision + hash + embedding model digest. Không cần Redis trong V1.
- Index giới hạn batch và ưu tiên request chat; không nạp nhiều model đồng thời mặc định trên máy 16 GB. Benchmark cả trường hợp chuyển model embedding/chat.
- Lưu tên/digest model embedding và số chiều cùng index version. Đổi embedding model phải build index mới và chuyển đổi sau kiểm tra, không trộn vector khác không gian.

### 6.3. Truy xuất và trả lời

- Tạo embedding câu hỏi, truy vấn theo owner/property/audience/permission/revision trước khi chọn ứng viên. Không lấy top-k toàn hệ thống rồi mới lọc ở phía ứng dụng.
- Khởi đầu exact vector search trên tập nhỏ đã lọc quyền; kiểm tra khả năng PostgreSQL/pgvector thực tế. Chỉ thêm approximate index khi kích thước và benchmark đòi hỏi.
- Lấy khoảng 12 ứng viên, loại trùng và chọn tối đa 5 đoạn vừa token budget. Đây là tham số thử nghiệm, không phải ngưỡng chất lượng đã chứng minh.
- Kiểm thử từ khóa riêng như mã phòng/tên chức năng. Chỉ thêm keyword fusion nếu eval cho thấy semantic search bỏ sót đáng kể.
- Calibrate ngưỡng từ chối trên câu hỏi trả lời được/không trả lời được; không coi một similarity score tùy ý là xác suất câu trả lời đúng.
- Prompt yêu cầu chỉ dùng bằng chứng được cung cấp; tài liệu là dữ liệu không đáng tin cậy về mặt chỉ dẫn, không có quyền đổi system prompt/tool.
- Output có `answer`, citation IDs và trạng thái cần làm rõ/không có căn cứ. Backend kiểm tra IDs nằm trong tập retrieved sources, loại hoặc từ chối citation giả.
- Tài liệu xung đột: ưu tiên phạm vi và phiên bản có hiệu lực được cấu hình rõ; nếu vẫn xung đột thì nêu chưa đủ căn cứ, không để model tự chọn chính sách.
- Không có nguồn phù hợp: trả lời rõ chưa tìm thấy tài liệu đã duyệt và gợi ý liên hệ người quản lý.

## 7. Tool nghiệp vụ trực tiếp

| Tool | Quyền staff tương ứng | Nguồn dữ liệu |
| --- | --- | --- |
| list_available_rooms | room.view | Rooms |
| list_outstanding_invoices | billing.view | Billing |
| get_monthly_report | report.view | Reports |
| list_expiring_leases | lease.view | Leases |
| list_open_maintenance | maintenance.view | Maintenance |
| get_my_invoices / get_my_leases / get_my_maintenance | Không dành cho staff | TenantPortal, dựa trên user ID |

- Mỗi tool nhận context xác thực riêng với arguments của model; không để model chỉ định landlord ID hoặc tenant user ID.
- Kiểm tra ownership mọi resource ID, validate ngày/enum/limit. Truy vấn SQL tự do và shell không tồn tại trong tool registry.
- Service trả số liệu chính xác, tổng số bản ghi, phân trang, phạm vi và thời điểm truy vấn. Không coi danh sách dashboard top vài mục là danh sách đầy đủ.
- Không để LLM tự cộng tiền hoặc tự suy ra trạng thái thanh toán. Số tiền trên card và câu số liệu quan trọng được tạo bằng template từ dữ liệu backend.
- Kỳ ngày theo Asia/Ho_Chi_Minh. Đối chiếu semantics service hiện tại trước khi tái sử dụng để không đổi cách tính của ứng dụng ngầm.
- Tên phòng trùng hoặc kỳ thanh toán mơ hồ thì hỏi lại. Phân biệt tiền đã lập hóa đơn, thực thu, chi phí và số dư nợ.

## 8. Database và API contract đề xuất

### 8.1. Các bảng mới

- `KnowledgeDocument`: owner/scope/audience, active revision, trạng thái thu hồi.
- `KnowledgeRevision`: nội dung immutable, phiên bản, hash, approval/effective dates.
- `KnowledgeChunk`: revision, ordinal, heading/offset, text, embedding và index version.
- `KnowledgeIngestionJob`: revision, trạng thái, attempts, lock expiry, mã lỗi.
- `ChatConversation`: owner user, role context, property scope, title, timestamps.
- `ChatMessage`: user/assistant role, text/cards, clientMessageId, processing status và request ID.
- `ChatMessageSource`: message, revision/chunk hoặc resource reference, quyền cần kiểm tra khi đọc lại.
- `ChatToolExecution`: tool, status, timing và mã lỗi; không log payload nhạy cảm mặc định.
- `ChatFeedback`: message, positive/negative, lý do tùy chọn.

Ràng buộc: unique revision/version; unique chunk ordinal theo revision/index; unique clientMessageId trong conversation; foreign keys và chính sách xóa rõ ràng. Nếu Prisma chưa biểu diễn được vector trong cấu hình hiện tại, dùng repository SQL parameterized và migration được kiểm tra, không raw SQL từ nội dung người dùng/model.

### 8.2. API dưới `/api/v1`

| Method / route | Hợp đồng chính |
| --- | --- |
| POST /chatbot/conversations | propertyId tùy chọn; server xác thực phạm vi và tạo conversation |
| GET /chatbot/conversations | Lịch sử của chính user, cursor pagination |
| GET /chatbot/conversations/:id/messages | Kiểm tra ownership và quyền nguồn hiện tại |
| POST /chatbot/conversations/:id/messages | `{message, clientMessageId}`; trả answer/cards/sources/status/requestId |
| DELETE /chatbot/conversations/:id | Xóa conversation và cascade dữ liệu liên quan |
| POST /chatbot/messages/:id/feedback | Đánh giá tin nhắn trong conversation của chính user |
| GET /knowledge/documents | Danh sách quản lý theo owner hoặc tài liệu dùng chung của admin |
| POST /knowledge/documents | Tạo draft từ text hoặc file được phép |
| POST /knowledge/documents/:id/revisions | Tạo bản nháp mới, không ghi đè bản đã duyệt |
| GET /knowledge/documents/:id/revisions/:revisionId | Preview cho người có quyền quản lý |
| POST /knowledge/documents/:id/revisions/:revisionId/publish | Duyệt revision, enqueue index; trả 202 và trạng thái |
| POST /knowledge/documents/:id/revoke | Thu hồi khỏi tìm kiếm ngay |
| DELETE /knowledge/documents/:id | Thu hồi và xóa nội dung/index theo job có theo dõi |
| POST /knowledge/documents/:id/revisions/:revisionId/reindex | Retry/rebuild cùng revision, idempotent |
| GET /knowledge/sources/:chunkId | Trả đúng đoạn nguồn đã duyệt nếu user vẫn có quyền xem |

- Không nhận history/system prompt/tool schema tùy ý từ client.
- POST message giới hạn 2.000 ký tự; mỗi conversation chỉ có một lượt active. Unique idempotency key ngăn chạy trùng do retry hoặc refresh token.
- Kết quả trả trạng thái `answered`, `needs_clarification`, `insufficient_evidence`; lỗi kỹ thuật dùng HTTP + error.code theo convention backend.
- Lỗi phân biệt: AI_UNAVAILABLE/AI_TIMEOUT/AI_BUSY/INVALID_REQUEST/RESOURCE_NOT_FOUND; không tiết lộ sự tồn tại resource của người khác.
- Client timeout không đồng nghĩa server chưa xử lý; retry cùng clientMessageId để lấy kết quả đã có hoặc trạng thái đang chạy.

## 9. Flutter và quản lý tri thức

### Chat

- Entry point từ dashboard landlord/staff, tenant portal và mục trợ giúp admin. Không thêm floating button trên mọi màn hình trong V1.
- Màn hình có phạm vi khu trọ, gợi ý câu hỏi theo vai trò, lịch sử, tạo mới và xóa hội thoại.
- Tin nhắn có trạng thái đang gửi/đang xử lý/lỗi; retry chống gửi trùng; câu trả lời hiển thị citation và thời điểm lấy số liệu.
- Citation mở sheet nguồn: tên tài liệu, phiên bản, mục, đoạn trích. Nguồn đã thu hồi báo không còn khả dụng, không mở link do model tự bịa.
- Card dữ liệu có nút mở chi tiết phòng/hóa đơn/bảo trì bằng route đã tồn tại và resource ID do server xác thực.
- Đổi property tạo conversation mới. Logout/đổi tài khoản hủy request, clear memory và chặn late response của phiên cũ.
- Cỡ chữ động, screen reader labels, bàn phím, màn hình nhỏ và empty/error state đều có widget test hoặc kiểm tra thiết bị.

### Knowledge management

- Landlord quản lý tài liệu riêng; admin quản lý hướng dẫn dùng chung, không browse tài liệu landlord.
- Danh sách có filter trạng thái, tiêu đề, phạm vi, phiên bản, ngày cập nhật và index status.
- Form tạo/sửa text hoặc nhập Markdown/TXT; chọn audience/property, preview và xác nhận xuất bản rõ ràng.
- Có thu hồi, xóa, retry index; hiển thị lý do index lỗi và tiến trình cơ bản.
- Staff và tenant không thấy quyền quản lý tài liệu trong V1; backend vẫn chặn API trực tiếp.

## 10. Bảo mật, lịch sử và giới hạn tài nguyên

- Quyền kiểm tra tại retrieval, tool execution, mở nguồn, đọc lịch sử và trước trả response. Không dựa vào UI hoặc prompt làm ranh giới quyền.
- Tin nhắn assistant có source dependencies. Khi quyền nguồn mất, ẩn nội dung dẫn xuất của tin nhắn khi đọc lại; không chỉ giấu citation còn giữ nguyên đoạn chứa dữ liệu.
- Không đưa tool outputs hoặc câu trả lời từ nguồn đã mất quyền vào context lượt mới. User-authored text vẫn được lưu như nội dung do user cung cấp, không trở thành bằng chứng được tin cậy.
- Context giới hạn theo token; ưu tiên câu hỏi hiện tại và bằng chứng mới. V1 không tạo summary lâu dài có thể giữ lại dữ liệu đã bị thu hồi.
- Không dùng cache chung xuyên user/landlord. Nếu cần cache sau benchmark, key gồm scope/role/permission/index version và phải có invalidation.
- Chat retention đề xuất 30 ngày, cleanup hàng ngày; xóa conversation xóa messages/sources/feedback tương ứng. Audit tối thiểu không chứa nội dung hội thoại có thể giữ lâu hơn theo chính sách vận hành được duyệt.
- Xóa tài liệu kéo theo cleanup chunks/embeddings/revisions và các bản trích lưu lặp; backup có thời hạn riêng, không hứa xóa tức thì khỏi backup.
- Mặc định không log prompt, JWT, số giấy tờ, tài khoản ngân hàng hoặc thông tin cá nhân đầy đủ. Log request ID, thời lượng, model version, tool name và error code.
- Cấu hình thử nghiệm: một lượt generation toàn hệ thống, tối đa 5 lượt chờ, một lượt/user, 5 request/phút/user; tối đa 2 vòng tool và 4 tool call/lượt.
- Deadline tổng 60 giây; timeout riêng Flutter cao hơn deadline backend. Mức này phải điều chỉnh qua benchmark, không làm request cũ treo vô hạn.
- Model context khởi điểm 4.096 token, đầu ra 512–768 token; có token budget cho prompt/history/sources/output. Không cố nhét 5 đoạn nếu vượt budget.
- Ollama chỉ trong mạng riêng/loopback, không public; không tự chuyển sang cloud khi local lỗi. Chatbot tắt vẫn không ảnh hưởng quản lý trọ thông thường.

## 11. File map dự kiến

Các đường dẫn dưới đây là dự kiến để giao việc, không phải file đã tạo.

### Backend: `backend`

- `src/ai/ollama.client.ts`, `src/ai/ai.module.ts`, `src/ai/ai.config.ts`: adapter/config dùng chung cho chat và embeddings.
- `src/chatbot/chatbot.module.ts`, `chatbot.controller.ts`, `chatbot.service.ts`: API và điều phối.
- `src/chatbot/chatbot-policy.service.ts`, `chatbot-context.service.ts`, `chatbot-response.service.ts`: quyền, context và validation output.
- `src/chatbot/tools/tool-registry.ts`, `tool-executor.service.ts`, `rental-tools.service.ts`, `tenant-tools.service.ts`: registry và nghiệp vụ read-only.
- `src/chatbot/dto/`: DTO conversations, messages và feedback theo contract mục 8.
- `src/knowledge/knowledge.module.ts`, `knowledge.controller.ts`, `knowledge.service.ts`: quản lý tài liệu/phiên bản.
- `src/knowledge/knowledge-policy.service.ts`, `knowledge-retrieval.service.ts`, `knowledge-indexer.service.ts`, `knowledge-worker.service.ts`, `knowledge-chunker.ts`, `knowledge-vector.repository.ts`: ACL, tìm kiếm, ingest và lưu vector.
- `src/knowledge/dto/`: DTO nhập tài liệu, phiên bản, publish và query.
- `knowledge/vi/`: tài liệu seed đã duyệt và manifest phiên bản; mẫu draft tách riêng, không tự publish.
- `prisma/schema.prisma`, `prisma/migrations/`: schema/migration mới; không rewrite migration cũ.
- `src/app.module.ts`, các module nghiệp vụ cần exports, `.env.example`, `README.md`: wiring và cấu hình.
- `src/chatbot/*.spec.ts`, `src/knowledge/*.spec.ts`, `test/e2e/chatbot.e2e-spec.ts`, `test/e2e/knowledge.e2e-spec.ts`: kiểm thử.
- `test/evals/chatbot-vi.json`, `scripts/evaluate-chatbot.ts`: bộ eval và runner sau khi duyệt.

### Flutter: `/Users/hoang/Rental_room_management`

- `lib/models/chatbot.dart`, `lib/models/knowledge.dart`: contracts.
- `lib/data/chatbot/chatbot_api.dart`, `chatbot_repository.dart`; `lib/data/knowledge/knowledge_api.dart`, `knowledge_repository.dart`: data access theo pattern hiện tại.
- `lib/features/chatbot/chatbot_providers.dart`, `chatbot_screen.dart`, `chatbot_history_screen.dart`, `widgets/`: UI chat/source/card.
- `lib/features/knowledge/knowledge_providers.dart`, `knowledge_list_screen.dart`, `knowledge_editor_screen.dart`, `knowledge_detail_screen.dart`: quản lý tài liệu.
- `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart`: routes và role navigation.
- Dashboard, tenant portal, settings/admin entry screens: chỉ sửa điểm vào cần thiết, giữ design system hiện tại.
- `test/data/chatbot/`, `test/data/knowledge/`, `test/features/chatbot/`, `test/features/knowledge/`: API/repository/widget/session isolation tests.

## 12. Kế hoạch thực hiện và các cổng duyệt

Mỗi giai đoạn triển khai sau duyệt sẽ chia thành các task nhỏ: viết test thất bại, xác nhận test bắt đúng thiếu sót, triển khai tối thiểu, chạy test và review diff. Không tự commit hoặc tạo branch khi chưa được yêu cầu.

| Giai đoạn | Đầu việc và sản phẩm bàn giao | Tiêu chí qua cổng | Ngày công dự kiến |
| --- | --- | --- | --- |
| 0. Khả thi | Xác minh Ollama/model/license, embedding API/dimension, pgvector/Prisma; benchmark bộ nhỏ trên Mac với app/backend cùng chạy | Chọn được cấu hình chất lượng/RAM/độ trễ chấp nhận; migration extension thử trên DB test | 1–2 |
| 1. Tri thức | Soạn 12 hướng dẫn/FAQ, 3 mẫu chính sách, metadata/audience; người dùng duyệt | Không có quy định tự bịa; tài liệu index đầu tiên đã được duyệt | 2–3 |
| 2. Quản lý/index | Schema, document/revision API, worker, chunking, embeddings, publish/revoke/delete | Ingest idempotent; thay phiên bản nguyên tử; thu hồi loại khỏi search ngay | 3–4 |
| 3. RAG end-to-end | Retrieval có ACL, trả lời/citation, hội thoại, fallback và limits | Đặt câu hỏi tài liệu và mở đúng nguồn; không lộ chéo tài khoản | 3–4 |
| 4. Tool nghiệp vụ | Phòng, công nợ, báo cáo, hợp đồng, bảo trì; phối hợp RAG/tool | Số liệu khớp service và không do LLM tính | 2–3 |
| 5. Flutter | Chat/history/source cards; quản lý tài liệu; route/session/error states | Hoàn tất luồng landlord trên simulator/thiết bị kiểm thử | 3–4 |
| 6. Vai trò | Tenant tools, staff permission matrix, admin tài liệu dùng chung | Vượt test role/ownership/revocation/history; không có admin bypass | 2–3 |
| 7. Nghiệm thu | Evals, lỗi runtime, tải nhỏ, cleanup, logs, runbook, feature flags | Đạt mục 13; có phương án tắt chatbot và rollback index | 2–3 |

Tổng dự kiến: **18–26 ngày công**, không gồm thời gian chờ duyệt nội dung, mua/cấp máy chủ hoặc sửa lỗi nền không thuộc chatbot. Đây là ước lượng cho V1 có RAG, quản lý tài liệu và ba vai trò nghiệp vụ, không phải cam kết thời hạn. Có thể demo landlord sớm sau giai đoạn 3 và một UI chat tối thiểu, nhưng chưa gọi đó là hoàn thiện V1.

## 13. Kiểm thử và nghiệm thu

### Bộ eval 100 tình huống

- 30 câu hỏi tài liệu có expected document/chunk và câu trả lời chuẩn.
- 15 câu không có căn cứ hoặc thiếu thông tin: phải từ chối/hỏi lại phù hợp.
- 20 câu nghiệp vụ và câu kết hợp RAG/tool: expected records/số liệu cố định.
- 20 câu phân quyền/injection: khác landlord/property/tenant, thiếu quyền staff, gọi nguồn trực tiếp, history và quyền bị thu hồi.
- 15 câu vòng đời/lỗi: sửa/xóa/publish tài liệu, ingest fail, đổi model, Ollama down, queue full, timeout, duplicate message và đổi phiên đăng nhập.

Mục tiêu đề xuất: retrieval recall@5 ít nhất 90% trên bộ tài liệu đủ căn cứ; câu trả lời đúng và có bằng chứng ít nhất 90% trên tập đó; citation ID hợp lệ 100%; số tiền trên card khớp fixture 100%; không rò rỉ ở bất kỳ test phân quyền nào. Không diễn giải việc pass bộ test hữu hạn là bảo đảm model không bao giờ sai.

Độ trễ: đo cold/warm và chuyển embedding/chat model; mục tiêu thử nghiệm p95 dưới 20 giây cho câu đơn giản khi warm, chưa cam kết trước benchmark. Đo peak RAM/swap với môi trường thật và hạ context/concurrency hoặc thay model nếu không đạt.

### Kiểm thử phần mềm

- Unit: chunking, token budget, DTO, tool permissions, source validation, index version, timeout và context loại nguồn hết quyền.
- Integration: vector query với ACL và dataset hai landlord; publish/revoke/index worker; service số liệu; cleanup và idempotency.
- E2E: JWT/ownership ở mọi endpoint, tenant liên kết lease, staff revoke permission trong conversation, model/tool lỗi không ảnh hưởng API khác.
- Flutter: parsing, role navigation, retry cùng ID, mở source/card, empty/error state, tài khoản A logout rồi B login không thấy late response của A.
- Mock Ollama trong CI phần mềm; chạy model thật bằng eval runner riêng, ghi model digest/config/dataset version.

Lệnh kiểm tra sau khi các test được tạo: backend `npm test -- --runInBand`, `npm run build`, `npm run test:e2e` trên DB test; Flutter `flutter analyze`, `flutter test`. Chạy tập test mới trước, sau đó regression. Không chạy migration hoặc e2e phá dữ liệu trên DB đang dùng.

## 14. Vận hành, bàn giao và rollback

- `.env.example` ghi feature flags AI_CHAT_ENABLED/RAG_ENABLED/BUSINESS_TOOLS_ENABLED, URL/model/digest, timeout, queue/rate limits, retention và index version; không chứa secret.
- Health trạng thái AI tách khỏi liveness nghiệp vụ; model down không làm toàn ứng dụng bị đánh dấu không dùng được.
- Runbook: khởi động, seed tài liệu đã duyệt, publish/reindex, giám sát lỗi, thu hồi tài liệu, xóa hội thoại và đổi model.
- Khi rollout lỗi: tắt feature flag; giữ nghiệp vụ hoạt động. Quay về model/index version trước bằng cấu hình; không drop bảng để rollback khẩn cấp.
- Backup DB/index cùng metadata; kiểm tra restore ở môi trường test. Ghi riêng retention backup để người dùng hiểu giới hạn xóa dữ liệu.
- Production cần host luôn hoạt động, TLS API, private inference network, giới hạn tài nguyên và kiểm thử sức tải. Không public Ollama trên Mac cá nhân để coi là production.
- Bàn giao: code, migrations, bộ tài liệu đã duyệt, model/index manifest, eval report, hướng dẫn quản lý tri thức và vận hành.

## 15. Phạm vi chưa bao gồm và kiểm chứng còn thiếu

- PDF/DOCX/OCR, hợp đồng riêng tư dạng file, streaming, voice, semantic reranker riêng, fine-tuning và thao tác ghi do chatbot khởi tạo nằm ngoài V1. Nếu người dùng muốn một mục trong V1, cập nhật phạm vi/ước lượng trước khi code.
- Nghiệp vụ hoàn cọc/hợp đồng không được chatbot kết luận như tư vấn pháp lý; chỉ diễn giải tài liệu đã duyệt và nêu nguồn, chuyển người quản lý khi thiếu căn cứ.
- Đã thử tra cứu tài liệu chính thức Ollama/pgvector trong lượt lập kế hoạch nhưng công cụ web không trả nội dung nguồn có thể kiểm chứng. Vì vậy lựa chọn model/embedding/extension là đề xuất có cổng xác minh, chưa khẳng định tương thích hoặc hiệu năng.
- Chưa cài/chạy Ollama, tải model, tạo extension, migrate DB hoặc benchmark. Không có code ứng dụng nào được sửa trong bước lập kế hoạch.

## 16. Checklist duyệt và theo dõi

- [ ] Người dùng duyệt kiến trúc Ollama + RAG + tool nghiệp vụ read-only.
- [ ] Người dùng duyệt V1 có quản lý tài liệu và mở dần landlord → tenant/staff.
- [ ] Người dùng duyệt định dạng đầu vào Markdown/TXT và quy trình duyệt nội dung.
- [ ] Người dùng duyệt phạm vi không có PDF/OCR/hợp đồng riêng tư dạng file trong V1.
- [ ] Người dùng duyệt local pilot, retention 30 ngày và ước lượng 18–26 ngày công.
- [ ] Giai đoạn 0 hoàn tất; chốt model, vector schema và baseline hiệu năng.
- [ ] Giai đoạn 1 hoàn tất; nội dung seed được duyệt.
- [ ] Giai đoạn 2 hoàn tất; vòng đời tài liệu/index được kiểm thử.
- [ ] Giai đoạn 3 hoàn tất; RAG có nguồn và phân quyền hoạt động.
- [ ] Giai đoạn 4 hoàn tất; tool read-only có dữ liệu chính xác.
- [ ] Giai đoạn 5 hoàn tất; Flutter chat và knowledge management hoạt động.
- [ ] Giai đoạn 6 hoàn tất; tenant/staff/admin scope được kiểm thử.
- [ ] Giai đoạn 7 hoàn tất; eval và runbook đạt nghiệm thu.

**Điểm dừng hiện tại:** chờ người dùng duyệt hoặc chỉnh kế hoạch. Không bắt đầu triển khai chỉ vì tài liệu này đã được lưu.

# Phương pháp và giới hạn kiểm chứng

Ngày 29/10/2026, snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## Hợp đồng nguồn

Catalog/FDD/Actor Matrix Giai đoạn 2 quyết định mã, tên, nhóm, mục tiêu, Actor và trạng thái. UML module Giai đoạn 3 quyết định associations đã chốt. Source hiện tại quyết định luồng, kiểm tra, dữ liệu và ngoại lệ; không suy tính năng từ tên file hoặc route. Giữ nguyên 11 bảng G01; 151 bảng mới có ghi chú nghiệp vụ thủ công tại `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/data/behavioral-analysis.json:1` và trích xuất schema/truy vết tại manifest.

Mỗi UC đúng một tiêu đề, một bảng hai cột/20 dòng dữ liệu. Dùng B1…Bn, A1…/E1… chỉ bước gốc, điều kiện, kết quả dữ liệu và điểm quay về/kết thúc. BR-01… là mã cục bộ trong UC, không là ID quy tắc toàn hệ thống. Bảng chỉ mô tả biến thể có source; không biến mỗi nút/API thành UC.

## Truy vết lớp triển khai

- UI1…: component Flutter và handler/line đã đọc; đây là điểm kiểm chứng, không khẳng định tất cả API của UC có một nút riêng. Ở màn hình dùng chung, handler nêu trong nhóm UI là chỉ mục component; bước nghiệp vụ vẫn đối chiếu với CLIENT/API/SVC, không chỉ tên callback.
- CLIENT1…: route client được nối bằng path với endpoint backend. Chuẩn hóa tham số đường dẫn chỉ để tìm evidence, không suy payload/quyền hay chấp nhận runtime.
- API1…: verb/path, Controller.method và role/capability theo handler; method-level override class. SVC1…/HELP… dẫn logic và helper điều kiện chéo field/ghi dữ liệu.
- DTO1…: lớp request/query, lớp gốc và nested DTO được giải theo TypeScript/import. Ô validation giữ kiểu, decorator, initializer. Hợp các DTO trong UC gồm các biến thể endpoint, không yêu cầu gửi tất cả field trong một payload.
- DB1…: model schema nguồn; không ngụ ý mọi model đều được ghi trong mọi bước. Với so sánh/ước tính local, ghi rõ không có DB persistence riêng.
- AUTH/JWT/GUARD/SCOPE/MFA/BOOT/ERR: chính sách xác thực, allowlist STAFF, validation/error chuẩn. Nguồn dùng chung không thay nguồn service đặc thù của UC.
- TEST1…: chỉ file có trong kết quả thực thi mới ghi đã chạy. Chỉ trích dẫn file E2E/Flutter không phải bằng chứng test đạt; test cùng module không chứng minh bao phủ mọi biến thể.
- UML1…: trang module đúng UC/association. Không suy include/extend từ việc dùng cùng service/DTO hoặc từ tiền điều kiện có dữ liệu trước.

Dòng source là một điểm bắt đầu để đọc method/class/model, không phải toàn bộ phạm vi chứng minh. Đường dẫn tuyệt đối phục vụ workspace hiện tại; khi chuyển máy cần đổi prefix, không đổi mã UC.

## Quyền và điều kiện đáng chú ý

STAFF dùng ANY permission khai báo tại handler, **sau đó** qua PropertyScopeInterceptor/ownership/business checks; ADMIN dùng ALL capability và các điều kiện MFA/step-up/service. Không có role kế thừa ADMIN→LANDLORD. Tenant scope của STAFF yêu cầu có lease trong scope và mọi lease/invoice của Tenant đều thuộc khu được giao. Chi tiết tại `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:25` và `/Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:23`.

TENANT tìm phòng và TENANT thuê là cùng role; cổng thuê cần Tenant liên kết và dữ liệu thuộc mình. Preset staff/admin, team member hoặc support agent không là Actor role mới. Provider ngoài chỉ xuất hiện có điều kiện theo Catalog, không có nghĩa tích hợp đã vận hành thực tế.

## Validation không được nâng quá source

`@IsOptional` cho phép bỏ qua validation khi vắng/null theo cơ chế DTO; `?` của TypeScript một mình không là validation runtime. Initializer là mặc định source, không mặc định mọi field phải nhập. Relation giữa field nằm ở service/helper. Một lớp query dùng chung có thể có field không có ý nghĩa ở mọi endpoint; payload chính xác xem chữ ký API tương ứng. ValidationPipe dùng whitelist/forbidNonWhitelisted/transform tại `/Users/hoang/Rental_room_management/backend/src/app.bootstrap.ts:52`. Không bổ sung giới hạn số/ngày chỉ theo suy đoán BA.

## Transaction và thất bại

Chỉ ghi rollback khi method/helper có transaction rõ. Một UC có nhiều lệnh, batch xử lý từng mục hoặc provider sau commit không có bảo đảm all-or-nothing toàn UC. BillingCommands lưu response chống trùng theo request hash, không bảo đảm email/SMS đã gửi. Trạng thái SENT của đường Zalo mock không phải kết quả provider thật. Không suy thông báo lỗi client có nghĩa DB chắc chắn chưa commit khi response bị mất.

## Kiểm định trong lượt này

71 suite/736 test backend đạt. Lệnh chạy lọc `backend/src/**/*.spec.ts`, bỏ `knowledge.repository.spec.ts` có PrismaClient/$connect; không chạy `backend/test/e2e/**` vì cần môi trường DB an toàn, có harness reset dữ liệu. HTTP unit dùng local server/mock không là UI/runtime trên deployment. Không gọi provider/scanner/Ollama/storage thật; không chạy Flutter/browser acceptance.

Parser markdown-it-py kiểm AST bảng, Node validator kiểm mã/coverage/nhãn/nguồn/dòng/UML/hash/test record. Không dùng kết quả parser/validator để tuyên bố quy tắc nghiệp vụ đã được nghiệp vụ nghiệm thu. `Source_Integrity_Result.json` so 846 source + gói Giai đoạn 2/3, kiểm riêng hash 11 G01 và diff tracked chỉ có tệp khóa Word đã cho phép xóa.

# Triển khai chatbot tài liệu — 22/10/2026

## Phạm vi đã có code

- Tái sử dụng backend task 0-3 trong backend, không tạo backend riêng hoặc thay storage vector.
- Task 4: API hỏi đáp/mở nguồn có JWT, chỉ LANDLORD, scope khu trọ, kiểm tra citation, kiểm tra lại nguồn sau generation, deadline, một inference slot và rate limit theo user.
- Task 5: Flutter model/API/repository/Riverpod state, timeout ask riêng 70 giây, giữ JWT refresh hiện có, hủy request và chặn response muộn khi đổi phiên/khu trọ.
- Task 6: chat độc lập từng câu, gợi ý, loading/error/retry, mở nguồn từ server; entry ở dashboard và menu. Giữ theme Manrope hiện tại, kiểm tra màn hình hẹp/text scaling/bàn phím.
- Task 7: dataset 30 ca, evaluator phần mềm/model, công cụ score distributions và runbook. Chưa hoàn thành nghiệm thu model thật hoặc bật pilot.

## File chính

- lib/models/chatbot.dart
- lib/data/chatbot/chatbot_api.dart và chatbot_repository.dart
- lib/features/chatbot/chatbot_providers.dart và chatbot_screen.dart
- lib/features/chatbot/widgets/chat_message_bubble.dart và chat_source_sheet.dart
- lib/app/app.dart, lib/features/auth/auth_navigation.dart, lib/features/dashboard/dashboard_screen.dart
- test/data/chatbot và test/features/chatbot

Backend: src/chatbot/chatbot.module.ts, chatbot.controller.ts, chatbot.service.ts, DTO/guard/filter; scripts/evaluate-chatbot.ts; test/evals/chatbot-mvp-vi.json; test/e2e/chatbot.e2e-spec.ts. Hướng dẫn chi tiết ở backend/docs/chatbot-api-and-pilot.md và chatbot-mvp-runbook.md.

## Kiểm chứng phần mềm

- Baseline trước thay đổi: backend 128 test đạt, 7 DB test bỏ qua do chưa truyền test DB; Flutter 116 test đạt.
- Sau triển khai: backend 153 unit/DB test đạt trên DB test riêng; chatbot E2E 23 test đạt với JWT và PostgreSQL thật, Ollama mock; Flutter 145 test đạt.
- npm run build đạt; flutter analyze không có issue. Software-only evaluator đạt 94 chatbot unit/DB test và 23 endpoint test; 20 ca chất lượng model được ghi rõ chưa chạy.
- E2E toàn backend có hai ca ngoài chatbot chưa đạt: lease-billing-dashboard.e2e-spec.ts:175 mong có hóa đơn ở tháng hiện tại nhưng nhận 0; tenant-portal-priority.e2e-spec.ts:153 mong 3.650.000 nhưng nhận 3.670.000. Không sửa logic hoặc fixture nghiệp vụ ngoài phạm vi chatbot.
- Migrations chỉ được áp dụng lên DB test mới rental_chatbot_test_20261022 trong lượt này. Không import corpus vào DB vận hành, không sửa .env đang dùng, không tự approve tài liệu, commit, push hoặc deploy.
- Đã render/kiểm tra UI Flutter với câu trả lời fixture; đây không phải demo model thật.
- E2E toàn backend: 30/32 test đạt, 2 lỗi nghiệp vụ nêu trên. git diff --check còn cảnh báo whitespace ở PROJECT_STATUS.md:3, file không được sửa trong lượt này.

## Điều kiện còn thiếu trước pilot

Ollama không chạy ở 127.0.0.1:11434 khi kiểm tra. Sáu tài liệu vẫn approved=false. Chưa có calibration RAG_MIN_SCORE hoặc bộ 30 request warm/model thật và chấm thủ công 15 câu theo checklist. Giữ CHATBOT_ENABLED=false cho đến khi các cổng này đạt. Kết quả smoke model ngày 17/10/2026 là dữ liệu lịch sử, không được coi là benchmark mới.

## Sử dụng và test

    flutter test test/data/chatbot test/features/chatbot
    flutter test
    flutter analyze
    flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1

Sau khi backend được bật đúng điều kiện, đăng nhập chủ trọ → dashboard → biểu tượng quyển sách → hỏi cách tạo hóa đơn → mở nguồn. Hỏi công nợ hiện tại phải nhận giải thích chưa hỗ trợ dữ liệu trực tiếp.

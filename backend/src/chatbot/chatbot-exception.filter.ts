import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { Response } from 'express';
import { ChatbotError } from './chatbot.types';

const errors: Record<string, [number, string]> = {
  AI_DISABLED: [503, 'Trợ lý tài liệu chưa được bật.'],
  AI_BUSY: [429, 'Trợ lý đang xử lý một câu hỏi khác. Vui lòng thử lại sau.'],
  AI_RATE_LIMITED: [429, 'Bạn đã gửi 5 câu hỏi trong một phút. Vui lòng chờ rồi thử lại.'],
  AI_TIMEOUT: [504, 'Trợ lý phản hồi quá lâu. Vui lòng thử lại.'],
  AI_UNAVAILABLE: [503, 'Model local hiện không khả dụng.'],
  AI_INVALID_RESPONSE: [502, 'Không thể xác minh câu trả lời và nguồn. Vui lòng thử lại.'],
  AI_INVALID_EMBEDDING: [502, 'Model embedding trả về dữ liệu không hợp lệ.'],
  AI_CONTEXT_LIMIT: [502, 'Câu hỏi và nguồn vượt giới hạn ngữ cảnh của model.'],
  AI_INVALID_INPUT: [400, 'Câu hỏi phải có từ 1 đến 1.000 ký tự.'],
  KNOWLEDGE_NOT_FOUND: [404, 'Nguồn không tồn tại hoặc đã bị thu hồi.'],
  KNOWLEDGE_SCOPE_NOT_FOUND: [404, 'Không tìm thấy khu trọ.'],
  KNOWLEDGE_INVALID_SCOPE: [404, 'Không tìm thấy phạm vi tài liệu.'],
  KNOWLEDGE_INDEX_INCOMPATIBLE: [503, 'Kho tài liệu cần được lập chỉ mục lại trước khi hỏi.'],
  KNOWLEDGE_CAPACITY_EXCEEDED: [503, 'Kho tài liệu vượt giới hạn pilot.'],
};

@Catch(ChatbotError)
export class ChatbotExceptionFilter implements ExceptionFilter {
  catch(error: ChatbotError, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();
    const [status, message] = errors[error.code] ?? [503, 'Trợ lý hiện chưa sẵn sàng.'];
    if (status === 429) response.setHeader('Retry-After', error.code === 'AI_BUSY' ? '5' : '60');
    response.status(status).json({ error: { code: error.code, message } });
  }
}

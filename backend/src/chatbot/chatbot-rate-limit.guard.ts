import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { AuthUser } from '../common/current-user.decorator';
import { ChatbotError } from './chatbot.types';

@Injectable()
export class ChatbotRateLimitGuard implements CanActivate {
  private readonly windows = new Map<string, { starts: number; count: number }>();

  canActivate(context: ExecutionContext): boolean {
    const { user } = context.switchToHttp().getRequest<{ user: AuthUser }>();
    const now = Date.now();
    for (const [id, window] of this.windows) {
      if (now - window.starts >= 60_000) this.windows.delete(id);
    }
    const window = this.windows.get(user.userId) ?? { starts: now, count: 0 };
    if (window.count >= 5) throw new ChatbotError('AI_RATE_LIMITED');
    window.count++;
    this.windows.set(user.userId, window);
    return true;
  }
}

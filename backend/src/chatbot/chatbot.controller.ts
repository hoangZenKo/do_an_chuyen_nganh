import { Body, Controller, Get, HttpCode, Param, Post, Query, UseFilters, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { ChatbotExceptionFilter } from './chatbot-exception.filter';
import { ChatbotRateLimitGuard } from './chatbot-rate-limit.guard';
import { ChatbotService } from './chatbot.service';
import { AskChatbotDto, SourceQueryDto } from './dto/ask-chatbot.dto';

@Controller('chatbot')
@UseGuards(AuthGuard('jwt'), RolesGuard)
@Roles(AuthRole.LANDLORD)
@UseFilters(ChatbotExceptionFilter)
export class ChatbotController {
  constructor(private readonly chatbot: ChatbotService) {}

  @Post('ask')
  @HttpCode(200)
  @UseGuards(ChatbotRateLimitGuard)
  async ask(@CurrentUser() user: AuthUser, @Body() input: AskChatbotDto) {
    return { data: await this.chatbot.ask(input.message, { landlordId: user.userId, propertyId: input.propertyId }) };
  }

  @Get('sources/:id')
  async source(@CurrentUser() user: AuthUser, @Param('id') id: string, @Query() query: SourceQueryDto) {
    return { data: await this.chatbot.getSource(id, { landlordId: user.userId, propertyId: query.propertyId }) };
  }
}

import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { detectFile } from '../uploads/uploads.service';
import { MalwareScannerService } from '../uploads/malware-scanner.service';
import { SupportAttachmentDto } from './support-workflow.dto';

@Injectable()
export class SupportAttachmentService {
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService, private readonly scanner: MalwareScannerService) {}

  private async ticket(actor: AuthUser, id: string, internal: boolean) {
    const staff = actor.role === 'admin' && actor.permissions?.includes('admin.support.read') && actor.permissions.includes('admin.support.manage');
    const ticket = await this.prisma.supportTicket.findFirst({ where: { id, ...(!staff ? { requesterId: actor.userId } : {}) } });
    if (!ticket || (!staff && internal)) throw new NotFoundException();
    if (staff && ticket.assigneeId && ticket.assigneeId !== actor.userId && !actor.permissions?.includes('admin.admins.manage')) throw new NotFoundException();
    return ticket;
  }

  async upload(actor: AuthUser, id: string, input: SupportAttachmentDto, file?: { buffer: Buffer; mimetype: string }) {
    const internal = input.internal === 'true';
    const ticket = await this.ticket(actor, id, internal);
    if (ticket.version !== input.version || ticket.mergedIntoId || ['RESOLVED', 'CLOSED'].includes(ticket.status)) throw new ConflictException('Ticket changed or closed.');
    if (!file || !file.buffer.length || file.buffer.length > 8 * 1024 * 1024) throw new BadRequestException('Select a file up to 8 MB.');
    const type = detectFile(file.buffer);
    if (!type || !['image/jpeg', 'image/png', 'image/webp', 'application/pdf'].includes(type.mime) || type.mime !== file.mimetype) throw new BadRequestException('File content and MIME must match a supported image or PDF.');
    const sha256 = await this.scanner.scan(file.buffer, type.mime);
    const filename = `${randomUUID()}.${type.extension}`;
    const directory = this.config.get<string>('UPLOADS_DIR') || join(process.cwd(), 'uploads');
    await mkdir(directory, { recursive: true });
    await writeFile(join(directory, filename), file.buffer, { flag: 'wx', mode: 0o600 });
    try {
      return await this.prisma.$transaction(async tx => {
        await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${id} FOR UPDATE`;
        const current = await tx.supportTicket.findUniqueOrThrow({ where: { id } });
        if (current.version !== input.version || current.mergedIntoId || ['RESOLVED', 'CLOSED'].includes(current.status)) throw new ConflictException('Ticket changed; upload again after reloading.');
        if (await tx.supportAttachment.count({ where: { ticketId: id } }) >= 20) throw new ConflictException('Maximum 20 attachments per ticket.');
        await tx.uploadedFile.create({ data: { filename, ownerId: actor.userId, mimeType: type.mime, purpose: 'SUPPORT_CLEAN' } });
        const data = await tx.supportAttachment.create({ data: { ticketId: id, filename, internal, sha256, size: file.buffer.length } });
        const updated = await tx.supportTicket.update({ where: { id }, data: { version: { increment: 1 } } });
        await platformAudit(tx, actor, 'support.attachment_added', 'support_ticket', id, 'Uploaded scanned support attachment', { attachmentId: data.id, sha256, internal });
        return { data: { ...data, version: updated.version, mimeType: type.mime } };
      });
    } catch (error) { await unlink(join(directory, filename)).catch(() => undefined); throw error; }
  }
}

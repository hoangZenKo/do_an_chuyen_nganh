import { validate } from 'class-validator';
import { CreatePaymentProofDto } from '../tenant-portal/dto/create-payment-proof.dto';
import { CreateTenantMaintenanceDto } from '../tenant-portal/dto/create-tenant-maintenance.dto';
import { CreateMaintenanceCommentDto } from '../maintenance/dto/create-maintenance-comment.dto';
import { CreateMaintenanceTicketDto } from '../maintenance/dto/create-maintenance-ticket.dto';
import { UpdateMaintenanceTicketDto } from '../maintenance/dto/update-maintenance-ticket.dto';
import { isAttachmentUrl } from './attachment-url.validator';

describe('Attachment URL validation', () => {
  it.each(['/uploads/1234-abcd.png', '/uploads/receipt.pdf', 'https://example.com/receipt.png', 'http://localhost:3000/uploads/proof.png'])('accepts %s', (value) => {
    expect(isAttachmentUrl(value)).toBe(true);
  });
  it.each(['', '/uploads/', '//evil.example/proof.png', '/uploads/../.env', '/uploads/%2e%2e%2fsecret', '/uploads/a.png?redirect=evil',
    'javascript:alert(1)', 'file:///etc/passwd', 'data:image/png;base64,abc', 'ftp://example.com/image.png', 'https://user:password@example.com/image.png', null, 1])('rejects %s', (value) => {
    expect(isAttachmentUrl(value)).toBe(false);
  });
  it('accepts the upload response across proof, maintenance and comment DTOs', async () => {
    const urls = ['/uploads/1234-abcd.png'];
    const proof = Object.assign(new CreatePaymentProofDto(), { amount: 100000, proofImageUrls: urls });
    const ticket = Object.assign(new CreateTenantMaintenanceDto(), { title: 'Repair tap', imageUrls: urls });
    const comment = Object.assign(new CreateMaintenanceCommentDto(), { body: 'Photo attached', imageUrls: urls });
    const ownerTicket = Object.assign(new CreateMaintenanceTicketDto(), { propertyId: '9ff07940-8145-4e9e-9d91-c1ac7e0c1199',
      roomId: '7a11abb6-d821-45bb-85c9-e9d804f0d13b', title: 'Repair tap', imageUrls: urls });
    const update = Object.assign(new UpdateMaintenanceTicketDto(), { imageUrls: urls });
    for (const input of [proof, ticket, comment, ownerTicket, update]) expect(await validate(input)).toHaveLength(0);
    proof.proofImageUrls = ['/uploads/ok.png', '/uploads/../secret'];
    expect(await validate(proof)).not.toHaveLength(0);
  });
});

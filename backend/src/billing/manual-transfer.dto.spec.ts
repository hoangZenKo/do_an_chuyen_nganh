import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { SaveTransferAccountDto } from './manual-transfer.dto';

describe('Manual transfer account validation', () => {
  const input = { version: 0, enabled: true, bankName: 'Bank test', accountName: 'OWNER', accountNumber: '00123456' };
  it('trims labels but preserves leading zeros', async () => {
    const dto = plainToInstance(SaveTransferAccountDto, { ...input, bankName: ' Bank test ', accountNumber: ' 00123456 ' });
    expect(await validate(dto)).toEqual([]);
    expect(dto.accountNumber).toBe('00123456');
    expect(dto.bankName).toBe('Bank test');
  });
  it.each([
    { bankName: ' ' }, { accountName: '' }, { accountNumber: '12' }, { accountNumber: '1234 5678' },
    { accountNumber: 'javascript:bad' }, { accountNumber: null }, { enabled: null }, { version: -1 },
    { qrImagePath: 'https://external.test/qr.png' }, { qrImagePath: '/uploads/../qr.png' }, { qrImagePath: '/uploads/proof.pdf' },
  ])('rejects malformed recipient settings: %j', async overrides => {
    expect((await validate(plainToInstance(SaveTransferAccountDto, { ...input, ...overrides }))).length).toBeGreaterThan(0);
  });
  it('accepts clearing an optional QR image without clearing the account', async () => {
    expect(await validate(plainToInstance(SaveTransferAccountDto, { ...input, qrImagePath: null }))).toEqual([]);
  });
});

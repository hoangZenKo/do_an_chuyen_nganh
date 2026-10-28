import { base32, totp } from './admin-mfa.service';

describe('Admin TOTP primitives', () => {
  it.each([
    [59, '94287082'], [1111111109, '07081804'], [1111111111, '14050471'],
    [1234567890, '89005924'], [2000000000, '69279037'], [20000000000, '65353130'],
  ])('matches RFC 6238 SHA1 vector at %s', (seconds, code) => {
    expect(totp(Buffer.from('12345678901234567890'), BigInt(Math.floor(Number(seconds) / 30)), 8)).toBe(code);
  });
  it('encodes authenticator secrets as unpadded base32', () => {
    expect(base32(Buffer.from('foobar'))).toBe('MZXW6YTBOI');
  });
});

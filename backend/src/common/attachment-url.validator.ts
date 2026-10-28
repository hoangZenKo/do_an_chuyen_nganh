import { isURL, ValidateBy, ValidationOptions } from 'class-validator';

export function isAttachmentUrl(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  if (/^\/uploads\/[a-zA-Z0-9][a-zA-Z0-9_.-]*$/.test(value)) return true;
  return isURL(value, { protocols: ['http', 'https'], require_protocol: true, require_tld: false, disallow_auth: true });
}

export function IsAttachmentUrl(options?: ValidationOptions): PropertyDecorator {
  return ValidateBy({ name: 'isAttachmentUrl', validator: {
    validate: isAttachmentUrl,
    defaultMessage: () => 'Attachment must be an HTTP(S) URL or a local /uploads/ file path.',
  } }, options);
}

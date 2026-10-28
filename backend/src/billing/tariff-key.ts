export function serviceKey(value: string) {
  return value.normalize('NFC').trim().toLowerCase();
}

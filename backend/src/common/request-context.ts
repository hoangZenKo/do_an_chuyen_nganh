import { AsyncLocalStorage } from 'node:async_hooks';

export const requestContext = new AsyncLocalStorage<{
  requestId: string;
  moderationSource?: string;
  device?: string;
  ip?: string;
}>();

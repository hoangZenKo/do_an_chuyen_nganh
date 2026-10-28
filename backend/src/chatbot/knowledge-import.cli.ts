import { resolve } from 'node:path';
import { ChatbotError } from './chatbot.types';

export function parseImportArgs(args: string[]): { manifest: string } {
  if (args.length !== 2 || args[0] !== '--manifest' || !args[1]?.trim()) {
    throw new ChatbotError('KNOWLEDGE_INVALID_ARGUMENTS');
  }
  return { manifest: resolve(args[1]) };
}

export function parseRevokeArgs(args: string[]): string {
  if (args.length !== 2 || args[0] !== '--key' ||
      !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(args[1])) {
    throw new ChatbotError('KNOWLEDGE_INVALID_ARGUMENTS');
  }
  return args[1];
}

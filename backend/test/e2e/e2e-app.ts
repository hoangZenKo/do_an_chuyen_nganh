import 'reflect-metadata';

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { configureApp } from '../../src/app.bootstrap';
import { AppModule } from '../../src/app.module';
import { PrismaService } from '../../src/prisma/prisma.service';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export interface E2eHarness {
  app: INestApplication;
  prisma: PrismaService;
  baseUrl: string;
  uploadDirectory: string;
}

export async function createE2eHarness(): Promise<E2eHarness> {
  const uploadDirectory = await mkdtemp(join(tmpdir(), 'rental-e2e-uploads-'));
  process.env.UPLOADS_DIR = uploadDirectory;
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = configureApp(moduleRef.createNestApplication());
  await app.listen(0, '127.0.0.1');

  const address = app.getHttpServer().address();
  if (!address || typeof address === 'string') {
    throw new Error('E2E server did not expose an address.');
  }

  return {
    app,
    prisma: app.get(PrismaService),
    baseUrl: `http://127.0.0.1:${address.port}`,
    uploadDirectory,
  };
}

export async function closeE2eHarness(harness: E2eHarness) {
  await harness.app.close();
  await rm(harness.uploadDirectory, { recursive: true, force: true });
}

export interface ApiResponse<T = any> {
  response: Response;
  status: number;
  text: string;
  json: T | null;
}

export async function requestJson<T = any>(
  baseUrl: string,
  path: string,
  init: {
    method?: string;
    token?: string;
    body?: unknown;
    headers?: Record<string, string>;
  } = {},
): Promise<ApiResponse<T>> {
  const response = await fetch(new URL(path, baseUrl), {
    method: init.method ?? 'GET',
    headers: {
      ...(init.body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(init.token ? { authorization: `Bearer ${init.token}` } : {}),
      ...(init.headers ?? {}),
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const text = await response.text();
  let json: T | null = null;
  if (text) {
    try {
      json = JSON.parse(text) as T;
    } catch {
      json = null;
    }
  }
  return { response, status: response.status, text, json };
}

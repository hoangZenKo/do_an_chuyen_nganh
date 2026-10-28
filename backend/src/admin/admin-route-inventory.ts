import 'reflect-metadata';
import { RequestMethod } from '@nestjs/common';
import { METHOD_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { ADMIN_PERMISSIONS_KEY, ADMIN_PRESETS } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { ROLES_KEY } from '../common/roles.constants';
import { sensitiveAdminAction } from '../auth/admin-step-up.policy';

export function adminRouteInventory(directory: string) {
  const files: string[] = [];
  function visit(folder: string) {
    for (const entry of readdirSync(folder, { withFileTypes: true })) {
      const path = join(folder, entry.name);
      if (entry.isDirectory()) visit(path);
      else if (/\.controller\.(ts|js)$/.test(entry.name) && !entry.name.endsWith('.d.ts')) files.push(path);
    }
  }
  visit(directory);
  const routes: { controller: string; handler: string; method: string; path: string; roles: string[]; permissions: string[]; presets: string[]; stepUp: string | null }[] = [];
  for (const file of files) {
    for (const exported of Object.values(require(file) as Record<string, unknown>)) {
      if (typeof exported !== 'function' || !Reflect.hasMetadata(PATH_METADATA, exported)) continue;
      const prototype = exported.prototype;
      for (const handler of Object.getOwnPropertyNames(prototype)) {
        const method = prototype[handler];
        if (handler === 'constructor' || typeof method !== 'function' || !Reflect.hasMetadata(METHOD_METADATA, method)) continue;
        const roles: string[] = Reflect.getMetadata(ROLES_KEY, method) ?? Reflect.getMetadata(ROLES_KEY, exported) ?? [];
        const prefixes: string[] = [Reflect.getMetadata(PATH_METADATA, exported)].flat();
        const suffixes: string[] = [Reflect.getMetadata(PATH_METADATA, method) ?? ''].flat();
        for (const prefix of prefixes) for (const suffix of suffixes) {
          const path = `/${[prefix, suffix].map(part => part.replace(/^\/+|\/+$/g, '')).filter(Boolean).join('/')}`;
          if (!path.startsWith('/admin') && !roles.includes(AuthRole.ADMIN)) continue;
          const verb = RequestMethod[Reflect.getMetadata(METHOD_METADATA, method) as RequestMethod];
          const permissions: string[] = Reflect.getMetadata(ADMIN_PERMISSIONS_KEY, method) ?? Reflect.getMetadata(ADMIN_PERMISSIONS_KEY, exported) ?? [];
          routes.push({ controller: exported.name, handler, method: verb, path, roles, permissions,
            presets: Object.entries(ADMIN_PRESETS).filter(([, granted]) => permissions.length > 0 && permissions.every(permission => (granted as readonly string[]).includes(permission))).map(([name]) => name),
            stepUp: sensitiveAdminAction(verb, path)?.action ?? null });
        }
      }
    }
  }
  return routes.sort((left, right) => left.path.localeCompare(right.path) || left.method.localeCompare(right.method));
}

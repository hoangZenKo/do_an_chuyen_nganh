import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { createServer } from 'node:net';
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { setTimeout as sleep } from 'node:timers/promises';
import { parseEnv } from 'node:util';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const backend = join(root, 'backend');
const sections = ['login', 'inventory', 'property', 'room', 'tenant', 'listing', 'housing',
  'contract', 'deposit', 'billing', 'maintenance', 'expense', 'renewal', 'occupants',
  'notifications', 'support', 'security', 'room-services', 'screens', 'staff', 'admin', 'checkout', 'regression'];
const results = [];
const children = new Set();
const fixtures = {};
let ui;
let prisma;
let options;
let output;
let simulatorId;
let interrupted = false;
let apiBase;
let testEnv;
let tokens = {};
const credentials = {};
const loginTimes = [];
const pendingCoverage = [
  'Native OS file/photo picker, PDF print/share sheet and external browser/Zalo/bank applications require separate native-device assertions.',
  'Live email/SMS, MFA enrollment, external storage and real payment providers are not exercised by the visible demo.',
  'Numbered UI scenarios do not cover every button or validation combination. coverage-inventory.json lists source actions requiring manual scenario/assertion mapping.',
];

export function assertLocalDatabase(value) {
  const url = new URL(value);
  assert.ok(['postgres:', 'postgresql:'].includes(url.protocol), 'PostgreSQL is required.');
  assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(url.hostname), 'Remote databases are refused.');
  assert.ok(url.pathname.length > 1, 'A source database name is required.');
  return url;
}

export function databaseForRun(value, timestamp, suffix, family = 'ui') {
  const url = assertLocalDatabase(value);
  assert.match(timestamp, /^\d+$/);
  assert.match(suffix, /^[a-f0-9]{12}$/);
  assert.match(family, /^(ui|functional|settlement|billing|admin_accounts|repairs|chatbot)$/);
  url.pathname = `/rental_${family}_test_${timestamp}_${suffix}`;
  url.search = '?schema=public';
  return url.toString();
}

export function parseOptions(args) {
  const parsed = { delay: 2000, sectionPause: 4000, sections: [...sections], inventory: false, keepDatabase: false };
  for (const arg of args) {
    if (arg === '--inventory') parsed.inventory = true;
    else if (arg === '--keep-database') parsed.keepDatabase = true;
    else if (/^--delay=\d+$/.test(arg)) parsed.delay = Number(arg.split('=')[1]);
    else if (/^--sections=/.test(arg)) parsed.sections = arg.slice(11).split(',');
    else if (/^--device=/.test(arg)) parsed.device = arg.slice(9);
    else throw new Error(`Unknown/invalid option: ${arg}`);
  }
  assert.ok(Number.isSafeInteger(parsed.delay) && parsed.delay <= 30000, 'Delay must be 0..30000 ms.');
  assert.ok(parsed.sections.length && parsed.sections.every(item => sections.includes(item)), 'Unknown section.');
  return parsed;
}

export function discoverRoutes(navigationSource, appSource) {
  const definitions = new Map([...navigationSource.matchAll(/const\s+(\w+Route)\s*=\s*'([^']+)'/g)]
    .map(match => [match[1], match[2]]));
  return [...new Set([...appSource.matchAll(/\bpath:\s*(\w+Route)\b/g)].map(match => match[1]))].map(name => {
    assert.ok(definitions.has(name), `Registered route not mapped: ${name}`);
    const path = definitions.get(name);
    const role = path.startsWith('/admin') ? 'admin' : path.startsWith('/tenant/') || path === '/tenant' ? 'tenant'
      : /^\/(explore|housing|auth|onboarding|splash|account\/activate|staff\/activate)/.test(path) ? 'public' : 'landlord';
    return { name, path, role, level: 'screen-only; business assertions listed separately' };
  });
}

export function resolveRoute(path, data) {
  if (!path.includes(':id')) return path;
  const key = /\/rooms\//.test(path) ? 'roomId' : /\/properties\//.test(path) ? 'propertyId'
    : /\/landlords\//.test(path) ? 'landlordId' : /\/tenants\//.test(path) ? 'tenantId'
      : /\/listings\//.test(path) ? 'listingId' : 'invoiceId';
  assert.ok(data[key], `Missing fixture ${key} for ${path}`);
  return path.replace(':id', encodeURIComponent(data[key]));
}

export function finder(kind, value, index = 0) {
  return Buffer.from(JSON.stringify({ finderType: 'DemoFinder', kind, value, index: String(index) })).toString('base64');
}

export function loginDelay(times, now, limit = 8, window = 61000) {
  const recent = times.filter(time => now - time < window);
  return recent.length < limit ? 0 : Math.max(0, recent[recent.length - limit] + window - now);
}

async function paceLogin() {
  const delay = loginDelay(loginTimes, Date.now());
  if (delay > 0) {
    console.log(`  Chờ ${Math.ceil(delay / 1000)}s để tôn trọng giới hạn đăng nhập của ứng dụng.`);
    await sleep(delay);
  }
  loginTimes.push(Date.now());
}

export async function runCase(collection, id, layer, dependencies, action) {
  const blocked = dependencies.filter(name => !collection.some(item => item.id === name && item.status === 'passed'));
  const result = { id, layer, status: 'running', startedAt: new Date().toISOString() };
  collection.push(result);
  if (blocked.length) {
    Object.assign(result, { status: 'blocked', error: `Prerequisites failed/not selected: ${blocked.join(', ')}` });
    return result;
  }
  try { await action(result); result.status = 'passed'; }
  catch (error) { result.status = 'failed'; result.error = error.stack ?? String(error); }
  result.finishedAt = new Date().toISOString();
  return result;
}

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, character => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[character]);

export async function writeReport(directory, entries, metadata) {
  await mkdir(directory, { recursive: true });
  const report = {
    ...metadata, generatedAt: new Date().toISOString(),
    success: entries.length > 0 && entries.every(item => item.status === 'passed'),
    allFunctionsVerified: false,
    notSelectedSections: sections.filter(section => !metadata.selectedSections?.includes(section)),
    counts: Object.fromEntries(['passed', 'failed', 'blocked'].map(status => [status, entries.filter(entry => entry.status === status).length])),
    results: entries
  };
  await writeFile(join(directory, 'report.json'), JSON.stringify(report, null, 2));
  await writeFile(join(directory, 'report.html'), `<!doctype html><html lang="vi"><meta charset="utf-8"><title>Rental System Demo</title>
    <style>body{font:16px Georgia;margin:32px;background:#f5f4ed;color:#182a35}table{border-collapse:collapse;width:100%}td,th{border:1px solid #aaa;padding:9px;text-align:left}pre{white-space:pre-wrap}.passed{color:#17603b}.failed,.blocked{color:#a52a22}</style>
    <h1>Kiểm thử hệ thống — ${escapeHtml(metadata.runId)}</h1>
    <p>${report.success ? 'Các ca đã chọn đều đạt; không có nghĩa mọi chức năng đã được kiểm chứng.' : 'Có lỗi hoặc ca bị chặn trong phạm vi đã chọn.'}</p>
    <p>screen = chỉ mở màn hình; UI = thao tác và xác nhận nghiệp vụ; regression = bộ kiểm thử tự động hiện có. Không đánh đồng ba mức này.</p>
    <p>Không chọn chạy: ${escapeHtml(report.notSelectedSections.join(', '))}. Không tính là đạt.</p>
    <table><tr><th>Phần</th><th>Mức kiểm thử</th><th>Kết quả</th><th>Chi tiết</th></tr>${entries.map(item => `<tr><td>${escapeHtml(item.id)}</td><td>${escapeHtml(item.layer)}</td><td class="${escapeHtml(item.status)}">${escapeHtml(item.status)}</td><td><pre>${escapeHtml(item.error ?? '')}</pre>${item.screenshot ? `<a href="${escapeHtml(item.screenshot)}">Ảnh</a>` : ''}</td></tr>`).join('')}</table>
    <h2>Phạm vi cần bổ sung/kiểm tra thủ công</h2><pre>${escapeHtml(JSON.stringify(metadata.pendingCoverage ?? [], null, 2))}</pre>
    <h2>Danh mục route từ mã nguồn</h2><pre>${escapeHtml(JSON.stringify(metadata.routes ?? [], null, 2))}</pre></html>`);
  return report;
}

function command(program, args, settings = {}) {
  return new Promise((resolveCommand, reject) => {
    const child = spawn(program, args, { cwd: root, env: testEnv ?? process.env, ...settings, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
    children.add(child);
    let text = '';
    let errorText = '';
    child.stdout.on('data', data => { text += data; settings.onOutput?.(data.toString()); });
    child.stderr.on('data', data => { errorText += data; settings.onOutput?.(data.toString()); });
    child.on('error', reject);
    child.on('close', code => {
      children.delete(child);
      if (code !== 0) reject(Object.assign(new Error(`${program} failed (${code})\n${(text + errorText).slice(-16000)}`), { output: text + errorText }));
      else resolveCommand(settings.includeStderr ? text + errorText : text);
    });
  });
}

function start(program, args, settings = {}) {
  const child = spawn(program, args, { cwd: root, env: testEnv ?? process.env, ...settings, detached: true, stdio: ['pipe', 'pipe', 'pipe'] });
  children.add(child);
  child.output = '';
  child.stdout.on('data', data => { child.output += data; });
  child.stderr.on('data', data => { child.output += data; });
  child.on('error', error => { child.startError = error; });
  child.on('exit', () => { children.delete(child); });
  return child;
}

export function stopOwned(child, killGroup = process.kill) {
  if (!child?.pid || child.exitCode !== null) return;
  try { killGroup(-child.pid, 'SIGTERM'); }
  catch (error) {
    if (error.code === 'ESRCH') return;
    try { child.kill('SIGTERM'); }
    catch (fallback) { console.error(`Could not stop owned process ${child.pid}: ${fallback.code}`); }
  }
}

async function waitUntil(probe, description, timeout = 60000) {
  const end = Date.now() + timeout;
  let last;
  while (Date.now() < end) {
    if (interrupted) throw new Error('Demo interrupted; cleaning up isolated resources.');
    try { const value = await probe(); if (value) return value; }
    catch (error) { last = error; }
    await sleep(350);
  }
  throw new Error(`Timeout: ${description}${last ? `: ${last.message}` : ''}`);
}

async function freePort() {
  const server = createServer();
  await new Promise(resolvePort => server.listen(0, '127.0.0.1', resolvePort));
  const port = server.address().port;
  await new Promise(resolveClose => server.close(resolveClose));
  return port;
}

async function sql(sourceUrl, statement) {
  const source = assertLocalDatabase(sourceUrl);
  const env = {
    ...process.env, PGHOST: source.hostname.replace(/[\[\]]/g, ''), PGPORT: source.port || '5432',
    PGUSER: decodeURIComponent(source.username), PGPASSWORD: decodeURIComponent(source.password), PGDATABASE: 'postgres', PGCONNECT_TIMEOUT: '10'
  };
  for (const key of ['PGSERVICE', 'PGSERVICEFILE', 'PGHOSTADDR', 'PGOPTIONS']) delete env[key];
  return command('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', statement], { env });
}

async function api(path, role = 'landlord', method = 'GET', body) {
  const response = await fetch(`${apiBase}/${path}`, {
    method, signal: AbortSignal.timeout(20000),
    headers: { 'content-type': 'application/json', ...(tokens[role] ? { authorization: `Bearer ${tokens[role]}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) })
  });
  const json = await response.json();
  assert.ok(response.ok, `${method} ${path}: ${response.status} ${JSON.stringify(json)}`);
  return json.data ?? json;
}

async function initializeFixtures() {
  const require = createRequire(join(backend, 'package.json'));
  const { PrismaClient } = require('@prisma/client');
  const argon2 = require('argon2');
  const { ADMIN_PRESETS } = require(join(backend, 'dist/src/common/admin-permissions.js'));
  const { STAFF_PERMISSIONS } = require(join(backend, 'dist/src/common/permissions.constants.js'));
  prisma = new PrismaClient({ datasources: { db: { url: testEnv.DATABASE_URL } } });
  const password = `Demo-${randomBytes(12).toString('base64url')}!a1`;
  const passwordHash = await argon2.hash(password);
  for (const [role, name] of [['landlord', 'Chu tro DEMO'], ['tenant', 'Nguoi thue DEMO'], ['staff', 'Nhan vien DEMO'], ['admin', 'Quan tri DEMO'], ['seeker', 'Nguoi tim phong DEMO']]) {
    credentials[role] = { email: `${role}.${randomBytes(5).toString('hex')}@example.test`, password, fullName: name };
    const user = await prisma.user.create({
      data: {
        email: credentials[role].email, fullName: name, passwordHash,
        phone: '+84900000000', role: role === 'seeker' ? 'TENANT' : role.toUpperCase(),
        ...(role === 'admin' ? { adminProfile: { create: { preset: 'super_admin', permissions: [...ADMIN_PRESETS.super_admin] } } } : {})
      }
    });
    fixtures[`${role}Id`] = user.id;
  }
  const property = await prisma.property.create({ data: { landlordId: fixtures.landlordId, name: 'Khu tro KIEM THU', address: 'Dia chi DEMO' } });
  fixtures.propertyId = property.id;
  const room = await prisma.room.create({ data: { propertyId: property.id, name: 'DEMO-A101', basePrice: 3000000, capacity: 4, areaSqm: 25, status: 'OCCUPIED', tenantName: credentials.tenant.fullName } });
  fixtures.roomId = room.id;
  const spare = await prisma.room.create({ data: { propertyId: property.id, name: 'DEMO-A102', basePrice: 3200000, capacity: 4, areaSqm: 28, status: 'VACANT' } });
  fixtures.spareRoomId = spare.id;
  const tenant = await prisma.tenant.create({ data: { landlordId: fixtures.landlordId, userId: fixtures.tenantId, fullName: credentials.tenant.fullName, phone: '+84900000001' } });
  fixtures.tenantUserId = fixtures.tenantId;
  fixtures.tenantId = tenant.id;
  const startDate = new Date(); startDate.setUTCDate(1); startDate.setUTCHours(0, 0, 0, 0);
  const endDate = new Date(); endDate.setUTCFullYear(endDate.getUTCFullYear() + 1);
  const lease = await prisma.lease.create({ data: { roomId: room.id, tenantId: tenant.id, monthlyRent: 3000000, deposit: 3000000, startDate, endDate } });
  fixtures.leaseId = lease.id;
  fixtures.renewalDate = `${endDate.getUTCFullYear() + 1}-12-31`;
  await prisma.staffProfile.create({
    data: {
      userId: fixtures.staffId, landlordId: fixtures.landlordId,
      fullName: credentials.staff.fullName, permissions: [...STAFF_PERMISSIONS], preset: 'manager',
      propertyScopes: { create: { propertyId: property.id, landlordId: fixtures.landlordId } }
    }
  });
  const listing = await prisma.roomListing.create({
    data: {
      roomId: spare.id, title: 'DEMO - Phong trong co ban cong',
      description: 'Du lieu kiem thu tu dong, khong phai tin cho thue that.', imageUrls: [], city: 'Hồ Chí Minh', district: 'Thủ Đức',
      publicAddress: 'Dia chi DEMO', monthlyRent: 3200000, deposit: 3000000, areaSqm: 28, amenities: ['Wifi'], status: 'PUBLISHED', publishedAt: new Date()
    }
  });
  fixtures.listingId = listing.id;
  for (const role of ['landlord', 'staff']) {
    await paceLogin();
    const response = await api('auth/login', role, 'POST', { email: credentials[role].email, password });
    tokens[role] = response.accessToken;
  }
  const month = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit' }).format(new Date());
  fixtures.month = month;
  const invoice = await api('billing/invoices', 'landlord', 'POST', { leaseId: lease.id, billingMonth: `${month}-01`, dueDate: `${month}-28`, otherAmount: 0 });
  fixtures.invoiceId = invoice.id;
  await writeFile(join(output, 'fixtures.json'), JSON.stringify({ ...fixtures, accounts: Object.fromEntries(Object.entries(credentials).map(([role, info]) => [role, { email: info.email }])) }, null, 2));
}

class DemoUI {
  constructor(driver) { this.driver = driver; this.role = null; this.steps = []; }
  async bridge(action, values = {}) {
    const result = await this.driver.execute('flutter:requestData', JSON.stringify({ action, ...values }));
    assert.notEqual(result?.isError, true, JSON.stringify(result));
    const message = result?.response?.message ?? result?.message ?? result;
    return typeof message === 'string' ? JSON.parse(message) : message;
  }
  async caption(text) {
    console.log(`  ${text}`);
    this.steps.push({ time: new Date().toISOString(), text });
    await this.bridge('caption', { text });
  }
  async pause() { await sleep(options.delay); }
  async go(path) {
    await this.caption(`${this.role ?? 'Khach'} → ${path}`);
    await this.bridge('route', { path });
    await this.pause();
    await waitUntil(async () => !(await this.snapshot()).texts.some(text => text === 'Đang tải...'), path);
  }
  async snapshot() { return this.bridge('snapshot'); }
  async reveal(target) {
    let found = false;
    const decoded = JSON.parse(Buffer.from(target, 'base64').toString());
    for (let attempt = 0; attempt < 14; attempt++) {
      if ((await this.bridge('matches', { kind: decoded.kind, value: decoded.value, index: Number(decoded.index) })).count > 0) {
        found = true; break;
      } else {
        if (attempt === 13) break;
        await this.driver.execute('flutter:scroll', finder('VerticalScrollable', '', -1), {
          dx: 0, dy: -450, durationMilliseconds: 350, frequency: 30,
        });
      }
    }
    assert.ok(found, 'Target was not built after scrolling.');
    await this.driver.execute('flutter:scrollIntoView', target, { alignment: 0.45, timeout: 10000 });
  }
  async tap(value, kind = 'Text', index = 0) {
    await this.caption(`Bấm: ${value}`);
    const target = finder(kind, value, index);
    await this.reveal(target);
    await this.driver.execute('flutter:waitForTappable', target, 8000);
    await this.driver.execute('flutter:clickElement', target, { timeout: 8000 });
    await this.pause();
  }
  async field(label, value, index = 0) {
    await this.caption(`Nhập: ${label}`);
    const target = finder('Field', label, index);
    await this.reveal(target);
    await this.driver.elementSendKeys(target, value);
    await this.pause();
  }
  async expect(text) {
    await waitUntil(async () => (await this.snapshot()).texts.some(value => value.includes(text)), `Expected text: ${text}`, 15000);
  }
  async login(role) {
    if (this.role === role) return;
    await this.caption(`ĐỔI VAI: ${role.toUpperCase()}`);
    await this.bridge('resetSession');
    this.role = null;
    await this.go('/auth/login');
    await this.field('Email address', credentials[role].email);
    await this.field('Password', credentials[role].password);
    await paceLogin(); await this.tap('Log In');
    await waitUntil(async () => {
      const state = await this.snapshot();
      return !state.route.startsWith('/auth') && state.sessionRole === (role === 'seeker' ? 'tenant' : role);
    }, `Login ${role}`, 20000);
    this.role = role;
  }
  async screenshot(name) {
    const filename = `${name.replace(/[^a-zA-Z0-9_-]/g, '_')}.png`;
    await command('xcrun', ['simctl', 'io', simulatorId, 'screenshot', join(output, filename)]);
    return filename;
  }
}

async function scenario(id, section, action, dependencies = ['login'], layer = 'UI') {
  if (interrupted) return;
  if (!options.sections.includes(section)) return;
  const result = await runCase(results, id, layer, dependencies, async entry => {
    console.log(`\n===== ${id} =====`);
    await ui.caption(id);
    await sleep(options.sectionPause);
    await ui.bridge('clearErrors');
    await action();
    const snapshot = await ui.snapshot();
    assert.deepEqual(snapshot.errors, [], 'Flutter runtime errors');
    entry.screenshot = await ui.screenshot(id);
  });
  if (result.status === 'failed') {
    console.error(result.error);
    result.screenshot = await ui.screenshot(`${id}-FAILED`).catch(() => undefined);
    await writeFile(join(output, `${id.replace(/[^a-zA-Z0-9_-]/g, '_')}-state.json`), JSON.stringify(await ui.snapshot().catch(() => ({})), null, 2));
  }
  console.log(`${result.status.toUpperCase()}: ${id}`);
  await writeFile(join(output, 'progress.json'), JSON.stringify(results, null, 2));
}

async function screenSweep(routes, role) {
  await ui.login(role);
  for (const entry of routes.filter(route => route.role === role || (role === 'tenant' && route.role === 'public'))) {
    if (interrupted) break;
    if (/^\/(splash|onboarding|auth|account\/activate|staff\/activate|tenant\/activate)/.test(entry.path)) continue;
    const check = await runCase(results, `screen:${role}:${entry.path}`, 'screen', [], async result => {
      const path = entry.path === '/leases/form' ? `/leases/form?tenantId=${fixtures.createdTenantId ?? fixtures.tenantId}` : resolveRoute(entry.path, fixtures);
      await ui.bridge('clearErrors');
      await ui.go(path);
      await sleep(Math.max(options.delay, 1200));
      const snapshot = await ui.snapshot();
      assert.equal(snapshot.route.split('?')[0], path.split('?')[0], 'Unexpected redirect / permission failure');
      assert.ok(snapshot.texts.filter(text => text.trim() && !text.includes('KIEM THU')).length > 0, 'Empty screen');
      assert.deepEqual(snapshot.errors, [], 'Flutter runtime errors');
      assert.ok(!snapshot.texts.some(text => /Không (?:thể )?tải|Exception:|INTERNAL_SERVER_ERROR|DioException/.test(text)), 'Screen displays a load failure');
      result.screenshot = await ui.screenshot(`screen-${role}-${entry.name}`);
    });
    if (check.status === 'failed') {
      console.error(`SCREEN FAILED: ${entry.path}: ${check.error?.split('\n')[0]}`);
      check.screenshot = await ui.screenshot(`screen-${role}-${entry.name}-FAILED`).catch(() => undefined);
    }
  }
}

async function buildInventory() {
  const routes = discoverRoutes(await readFile(join(root, 'lib/features/auth/auth_navigation.dart'), 'utf8'), await readFile(join(root, 'lib/app/app.dart'), 'utf8'));
  const dartFiles = (await command('rg', ['--files', 'lib/features'])).trim().split('\n').filter(path => path.endsWith('.dart'));
  const actions = [];
  for (const path of dartFiles) {
    const text = await readFile(join(root, path), 'utf8');
    for (const match of text.matchAll(/(?:label:\s*const Text|child:\s*const Text|tooltip:)[(\s]*'([^']+)'/g)) {
      actions.push({ file: path, line: text.slice(0, match.index).split('\n').length, text: match[1], status: 'requires scenario/assertion mapping' });
    }
  }
  const apiSuites = (await readdir(join(backend, 'test/e2e'))).filter(name => name.endsWith('.e2e-spec.ts') && !name.includes('.local.')).sort();
  const widgetSuites = (await command('rg', ['--files', 'test', '-g', '*_test.dart'])).trim().split('\n').filter(path => !path.startsWith('test/system_demo/'));
  const scriptSuites = (await readdir(join(backend, 'scripts'))).filter(name => name.endsWith('.test.mjs')).sort();
  return { routes, actions, apiSuites, widgetSuites, scriptSuites };
}

async function visualJourneys(inventory) {
  // Các phần nghiệp vụ được định nghĩa bên dưới; không gửi API thay cho bấm nút UI.
  await journeys(inventory);
}

async function openLifecycle(role) {
  await ui.login(role);
  if (role === 'tenant') {
    await ui.go('/tenant/leases');
    await ui.tap('Phòng DEMO-A101 · Khu tro KIEM THU', 'Text');
    await ui.tap('Yêu cầu, người ở cùng & quyết toán');
  } else {
    await ui.go(`/tenants/${fixtures.tenantId}`);
    await ui.tap('Yêu cầu & người ở cùng');
  }
  await ui.expect('Yêu cầu & người ở cùng');
}

async function journeys(inventory) {
  // PHẦN 01: Đăng nhập lần lượt người thuê, chủ trọ, nhân viên và admin.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login --delay=2500
  await scenario('login', 'login', async () => {
    for (const role of ['tenant', 'landlord', 'staff', 'admin']) await ui.login(role);
  }, []);

  // PHẦN 02: Đăng ký người tìm trọ mới; kiểm tra tài khoản được tạo thật.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,inventory --delay=2500
  await scenario('02-dang-ky-nguoi-thue', 'inventory', async () => {
    await ui.bridge('resetSession'); ui.role = null;
    await ui.go('/auth/register');
    const email = `new.${randomBytes(6).toString('hex')}@example.test`;
    await ui.field('Full name', 'Nguoi tim phong DEMO');
    await ui.field('Email address', email);
    await ui.field('Phone number', '0900000002');
    await ui.field('Password', credentials.tenant.password);
    await ui.field('Confirm password', credentials.tenant.password);
    await ui.tap('Checkbox', 'Type');
    await ui.tap('Sign Up');
    await waitUntil(() => prisma.user.findUnique({ where: { email } }), 'registered seeker');
    const user = await prisma.user.findUniqueOrThrow({ where: { email } });
    assert.equal(user.role, 'TENANT');
    assert.equal(await prisma.tenant.count({ where: { userId: user.id } }), 0);
    ui.role = null;
  });

  // PHẦN 03: Chủ trọ tạo và sửa khu trọ, kiểm tra dữ liệu lưu trên máy chủ.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,property --delay=2500
  await scenario('03-tao-sua-khu-tro', 'property', async () => {
    await ui.login('landlord'); await ui.go('/properties/form');
    await ui.field('Tên khu trọ', 'Khu tro tao bang UI DEMO');
    await ui.field('Địa chỉ', 'Dia chi du lieu thu nghiem');
    await ui.tap('Tạo khu trọ');
    const property = await waitUntil(() => prisma.property.findFirst({ where: { landlordId: fixtures.landlordId, name: 'Khu tro tao bang UI DEMO' } }), 'property creation');
    fixtures.createdPropertyId = property.id;
    await ui.go(`/properties/form?propertyId=${property.id}`);
    await ui.field('Tên khu trọ', 'Khu tro UI DEMO da sua');
    await ui.tap('Lưu thay đổi');
    await waitUntil(async () => (await prisma.property.findUniqueOrThrow({ where: { id: property.id } })).name.endsWith('da sua'), 'property edit');
  });

  // PHẦN 04: Chủ trọ tạo phòng, sửa thông tin và kiểm tra 4 tab chi tiết.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,room --delay=2500
  await scenario('04-tao-sua-phong', 'room', async () => {
    await ui.login('landlord'); await ui.go('/dashboard');
    await ui.go('/properties'); await ui.tap('Khu tro KIEM THU');
    await ui.go('/rooms/form');
    await ui.field('Tên phòng', 'UI-DEMO-B201');
    await ui.field('Tầng', '2');
    await ui.field('Diện tích (m²)', '28');
    await ui.field('Giá thuê (đ)', '3500000');
    await ui.field('Sức chứa (người)', '3');
    await ui.tap('Tạo phòng');
    const room = await waitUntil(() => prisma.room.findFirst({ where: { name: 'UI-DEMO-B201', property: { landlordId: fixtures.landlordId } } }), 'room creation');
    fixtures.createdRoomId = room.id;
    await ui.go(`/rooms/form?roomId=${room.id}`);
    await ui.field('Ghi chú', 'DEMO da chinh sua');
    await ui.tap('Lưu thay đổi');
    await waitUntil(async () => (await prisma.room.findUniqueOrThrow({ where: { id: room.id } })).note === 'DEMO da chinh sua', 'room edit');
    await ui.go(`/rooms/${room.id}`);
    for (const tab of ['Info', 'Ảnh', 'Lịch', 'Hợp đồng']) await ui.tap(tab);
  });

  // PHẦN 05: Thêm người thuê, tìm kiếm, sửa hồ sơ và nút quay lại.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,tenant --delay=2500
  await scenario('05-tao-sua-tim-nguoi-thue', 'tenant', async () => {
    await ui.login('landlord'); await ui.go('/tenants/form');
    await ui.field('Họ tên', 'Nguoi thue UI DEMO');
    await ui.field('Số điện thoại', '0900000003');
    await ui.field('CCCD/CMND', '000000000003');
    await ui.field('Ghi chú', 'Tai khoan kiem thu');
    await ui.tap('Thêm người thuê');
    const tenant = await waitUntil(() => prisma.tenant.findFirst({ where: { landlordId: fixtures.landlordId, fullName: 'Nguoi thue UI DEMO' } }), 'tenant creation');
    fixtures.createdTenantId = tenant.id;
    await ui.go('/tenants');
    await ui.field('Tìm theo tên, SĐT, số phòng...', 'Nguoi thue UI DEMO');
    await ui.expect('Nguoi thue UI DEMO');
    await ui.go(`/tenants/form?tenantId=${tenant.id}`);
    await ui.field('Ghi chú', 'Ho so DEMO da sua');
    await ui.tap('Lưu thay đổi');
    await waitUntil(async () => (await prisma.tenant.findUniqueOrThrow({ where: { id: tenant.id } })).note === 'Ho so DEMO da sua', 'tenant edit');
    await ui.go(`/rooms/${fixtures.roomId}`); await ui.tap('Hợp đồng'); await ui.tap('Hồ sơ');
    await ui.tap('Quay lại', 'Tooltip'); await ui.expect('NGƯỜI THUÊ HIỆN TẠI');
  });

  // PHẦN 06: Chủ trọ tạo tin mới và gửi duyệt; admin phê duyệt nội dung.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,room,listing --delay=2500
  await scenario('06-tin-dang-va-kiem-duyet', 'listing', async () => {
    await ui.login('landlord'); await ui.go('/listings'); await ui.tap('Tạo tin');
    await ui.tap('Chọn phòng trống');
    await ui.tap('UI-DEMO-B201', 'Contains');
    for (const [label, value] of Object.entries({
      'Tiêu đề': 'DEMO tin dang UI', 'Mô tả công khai': 'Tin thu nghiem tu dong, khong giao dich that.',
      'Tỉnh / Thành phố': 'Hồ Chí Minh', 'Quận / Huyện': 'Thủ Đức', 'Địa chỉ được phép công khai': 'Duong DEMO',
      'Giá thuê (đ/tháng)': '3500000', 'Tiền cọc (đ)': '3000000', 'Diện tích (m²)': '28',
      'Ảnh (mỗi dòng một URL ảnh)': 'https://example.test/demo.png'
    })) await ui.field(label, value);
    await ui.tap('Lưu bản nháp');
    await ui.tap('Gửi duyệt'); await ui.tap('Xác nhận', 'Text', -1);
    await waitUntil(async () => (await prisma.roomListing.findFirst({ where: { title: 'DEMO tin dang UI' } }))?.status === 'PENDING', 'listing submitted');
    await ui.login('admin'); await ui.go('/admin/listings');
    await ui.tap('Duyệt'); await ui.tap('Xác nhận');
    const listing = await prisma.roomListing.findFirst({ where: { title: 'DEMO tin dang UI' } });
    assert.equal(listing?.status, 'PUBLISHED');
  }, ['login', '04-tao-sua-phong']);

  // PHẦN 07: Người thuê xem tin, lưu yêu thích và mở danh sách đã lưu.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,housing --delay=2500
  await scenario('07-kham-pha-va-yeu-thich', 'housing', async () => {
    await ui.login('tenant'); await ui.go(`/explore/listings/${fixtures.listingId}`);
    await ui.tap('Lưu yêu thích');
    await waitUntil(() => prisma.savedListing.findUnique({ where: { userId_listingId: { userId: fixtures.tenantUserId, listingId: fixtures.listingId } } }), 'favorite saved');
    await ui.go('/housing/favorites'); await ui.expect('DEMO - Phong trong co ban cong');
  });

  // PHẦN 07B: Đặt, đổi, hủy lịch; chủ trọ xác nhận, đánh dấu đã xem sớm và tạo hợp đồng.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,housing --delay=2500
  await scenario('07b-dat-lich-den-tao-hop-dong', 'housing', async () => {
    await ui.login('seeker'); await ui.go(`/explore/listings/${fixtures.listingId}`);
    await ui.tap('Đặt lịch xem phòng');
    await ui.field('Ghi chú (không bắt buộc)', 'DEMO muon xem phong, khong can doi toi gio hen');
    await ui.tap('Xác nhận');
    const viewing = await waitUntil(() => prisma.roomViewing.findFirst({ where: { studentId: fixtures.seekerId, status: 'REQUESTED' } }), 'viewing request');
    await ui.go('/housing/viewings'); await ui.tap('Đổi lịch');
    await ui.field('Ghi chú (không bắt buộc)', 'DEMO gui lai lich, chu tro can xac nhan lai');
    await ui.tap('Xác nhận');
    await waitUntil(async () => (await prisma.roomViewing.findUniqueOrThrow({ where: { id: viewing.id } })).version > viewing.version, 'reschedule version');
    await ui.tap('Hủy lịch'); await ui.field('Lý do hủy lịch', 'DEMO kiem tra huy lich roi dat lai');
    await ui.tap('Xác nhận');
    await waitUntil(async () => (await prisma.roomViewing.findUniqueOrThrow({ where: { id: viewing.id } })).status === 'CANCELLED', 'cancel viewing');
    await ui.go(`/explore/listings/${fixtures.listingId}`); await ui.tap('Đặt lịch xem phòng');
    await ui.field('Ghi chú (không bắt buộc)', 'DEMO lich moi'); await ui.tap('Xác nhận');
    const current = await waitUntil(() => prisma.roomViewing.findFirst({ where: { studentId: fixtures.seekerId, status: 'REQUESTED' } }), 'second booking');
    await ui.login('landlord'); await ui.go('/housing/viewings');
    await ui.tap('Xác nhận lịch'); await ui.tap('Xác nhận', 'Text', -1);
    await waitUntil(async () => (await prisma.roomViewing.findUniqueOrThrow({ where: { id: current.id } })).status === 'CONFIRMED', 'confirm viewing');
    await ui.tap('Đã xem phòng'); await ui.tap('Xác nhận', 'Text', -1);
    await waitUntil(async () => (await prisma.roomViewing.findUniqueOrThrow({ where: { id: current.id } })).status === 'COMPLETED', 'complete viewing before scheduled time');
    await ui.tap('Tạo hợp đồng'); await ui.field('Tiền thuê / tháng', '3200000');
    await ui.field('Tiền cọc thỏa thuận', '3000000'); await ui.tap('Xác nhận', 'Text', -1);
    const linked = await waitUntil(async () => {
      const record = await prisma.roomViewing.findUniqueOrThrow({ where: { id: current.id } });
      return record.status === 'LEASED' && record.leaseId ? record : null;
    }, 'lease from viewing');
    fixtures.viewingLeaseId = linked.leaseId;
    assert.equal(await prisma.depositTransaction.count({ where: { leaseId: linked.leaseId } }), 0, 'Creating lease must not silently collect money.');
    await ui.login('seeker'); await ui.go('/tenant/leases'); await ui.expect('DEMO-A102');
  });

  // PHẦN 08: Hợp đồng đang thuê, thông tin phòng và đối chiếu cọc hai vai trò.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,contract --delay=2500
  await scenario('08-hop-dong-va-ban-giao', 'contract', async () => {
    await ui.login('tenant'); await ui.go('/tenant/leases');
    await ui.tap('Phòng DEMO-A101 · Khu tro KIEM THU', 'Text'); await ui.expect('Lịch sử tiền cọc');
    await ui.tap('Bàn giao & đối chiếu cọc');
    await ui.login('landlord'); await ui.go(`/tenants/${fixtures.tenantId}`);
    await ui.tap('Bàn giao & tiền cọc');
    await ui.field('Chỉ số điện ban đầu (kWh)', '100');
    await ui.field('Chỉ số nước ban đầu (m³)', '10');
    await ui.field('Hiện trạng, tài sản và hư hỏng có sẵn', 'DEMO phong nguyen ven, thiet bi hoat dong binh thuong');
    await ui.tap('Lưu biên bản bàn giao');
    await ui.login('tenant'); await ui.go('/tenant/leases');
    await ui.tap('Phòng DEMO-A101 · Khu tro KIEM THU', 'Text'); await ui.tap('Bàn giao & đối chiếu cọc');
    await ui.tap('Checkbox', 'Type'); await ui.tap('Xác nhận đã nhận phòng');
    await waitUntil(async () => Boolean((await prisma.leaseHandover.findUnique({ where: { leaseId: fixtures.leaseId } }))?.acceptedAt), 'handover accepted');
    assert.equal((await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } })).status, 'ACTIVE');
  });

  // PHẦN 09: Chủ trọ ghi nhận thu cọc; người thuê thấy sổ cọc cập nhật.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,deposit --delay=2500
  await scenario('09-thu-coc-va-doi-chieu', 'deposit', async () => {
    await ui.login('landlord'); await ui.go(`/tenants/${fixtures.tenantId}`);
    await ui.tap('Cọc'); await ui.field('Số tiền', '3000000');
    await ui.field('Ghi chú', 'DEMO khong phat sinh tien that'); await ui.tap('Lưu');
    await waitUntil(async () => (await prisma.depositTransaction.count({ where: { leaseId: fixtures.leaseId } })) === 1, 'deposit ledger');
    await ui.login('tenant'); await ui.go('/tenant/leases');
    await ui.tap('Phòng DEMO-A101 · Khu tro KIEM THU', 'Text'); await ui.expect('3.000.000');
    assert.equal((await prisma.depositTransaction.findFirst({ where: { leaseId: fixtures.leaseId } })).amount, 3000000);
  });

  // PHẦN 10: Người thuê upload chứng từ; chủ trọ duyệt và kiểm tra số dư.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,billing --delay=2500
  await scenario('10-hoa-don-va-thanh-toan', 'billing', async () => {
    await ui.login('tenant'); await ui.go(`/tenant/invoices/${fixtures.invoiceId}`); await ui.expect('3.000.000');
    await ui.tap('Gửi chứng từ khoản đã thanh toán');
    await ui.field('Số tiền đã trả', '3000000');
    await ui.field('Ghi chú', 'DEMO khong chuyen tien that');
    await ui.tap('Upload ảnh/chứng từ'); await ui.expect('Đã upload 1 file');
    await ui.tap('Gửi');
    const proof = await waitUntil(() => prisma.paymentProof.findFirst({ where: { invoiceId: fixtures.invoiceId } }), 'proof submitted');
    assert.equal(proof.status, 'PENDING');
    assert.equal((await prisma.invoice.findUniqueOrThrow({ where: { id: fixtures.invoiceId } })).paidAmount, 0);
    await ui.login('landlord'); await ui.go(`/billing/${fixtures.invoiceId}`);
    await ui.tap('Duyệt');
    await ui.tap('Checkbox', 'Type');
    await ui.field('Ghi chú cho thanh toán', 'DEMO xac nhan thu gia lap');
    await ui.tap('Duyệt', 'Text', -1);
    await waitUntil(async () => (await prisma.invoice.findUniqueOrThrow({ where: { id: fixtures.invoiceId } })).paidAmount === 3000000, 'invoice paid');
    await ui.login('tenant'); await ui.go(`/tenant/invoices/${fixtures.invoiceId}`); await ui.expect('Đã thanh toán');
  });

  // PHẦN 10B: Chủ trọ tạo hóa đơn thật qua form nhiều bước và người thuê kiểm tra kỳ mới.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,billing --delay=2500
  await scenario('10b-tao-hoa-don-qua-giao-dien', 'billing', async () => {
    await ui.login('landlord'); await ui.go('/billing/form');
    await ui.tap('DropdownButtonFormField<BillingLease>', 'Type');
    await ui.tap('Phòng DEMO-A101 - Nguoi thue DEMO', 'Text', -1);
    const next = new Date(); next.setUTCMonth(next.getUTCMonth() + 1, 1);
    const month = next.toISOString().slice(0, 7);
    await ui.field('Tháng thanh toán', `${month}-01`);
    await ui.field('Hạn thanh toán', `${month}-28`);
    await ui.field('Ghi chú (tùy chọn)', 'DEMO tao hoa don qua UI');
    await ui.tap('Tiếp tục: Khoản thu');
    await ui.tap('Switch', 'Type', 0); await ui.tap('Switch', 'Type', 1);
    await ui.tap('Chi tiết');
    await ui.tap('Gửi hóa đơn');
    const invoice = await waitUntil(() => prisma.invoice.findFirst({ where: { leaseId: fixtures.leaseId, note: 'DEMO tao hoa don qua UI' } }), 'UI invoice creation');
    assert.equal(invoice.totalAmount, 3000000);
    await ui.login('tenant'); await ui.go(`/tenant/invoices/${invoice.id}`); await ui.expect('3.000.000');
    await ui.login('landlord'); await ui.go(`/billing/${invoice.id}`);
    await ui.tap('Hủy hóa đơn'); await ui.field('Lý do hủy', 'DEMO ket thuc kiem thu hoa don ky moi');
    await ui.tap('Hủy hóa đơn', 'ButtonText', -1);
    await waitUntil(async () => (await prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).status === 'CANCELLED', 'invoice cancellation');
  });

  // PHẦN 11: Người thuê báo sự cố → chủ trọ phản hồi → xử lý → hoàn tất.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,maintenance --delay=2500
  await scenario('11-sua-chua-hai-vai-tro', 'maintenance', async () => {
    await ui.login('tenant'); await ui.go('/tenant/maintenance'); await ui.tap('Báo sự cố');
    await ui.field('Tiêu đề', 'DEMO - Voi nuoc bi ro');
    await ui.field('Mô tả', 'Su co gia lap, khong phai su co that'); await ui.tap('Gửi yêu cầu');
    const ticket = await waitUntil(() => prisma.maintenanceTicket.findFirst({ where: { title: 'DEMO - Voi nuoc bi ro', propertyId: fixtures.propertyId } }), 'repair submitted');
    fixtures.ticketId = ticket.id;
    await ui.login('landlord'); await ui.go('/maintenance');
    await ui.tap('PopupMenuButton<String>', 'Type'); await ui.tap('Đang xử lý', 'Text', -1);
    await waitUntil(async () => (await prisma.maintenanceTicket.findUniqueOrThrow({ where: { id: ticket.id } })).status === 'IN_PROGRESS', 'repair accepted');
    await ui.tap('PopupMenuButton<String>', 'Type'); await ui.tap('Phản hồi');
    await ui.field('Phản hồi', 'DEMO da tiep nhan va kiem tra'); await ui.tap('Gửi');
    await ui.tap('PopupMenuButton<String>', 'Type'); await ui.tap('Hoàn tất');
    await ui.field('Chi phí thực tế', '0'); await ui.field('Ghi chú', 'DEMO da hoan tat');
    await ui.tap('Tạo chi phí sửa chữa'); await ui.tap('Hoàn tất', 'Text', -1);
    await waitUntil(async () => (await prisma.maintenanceTicket.findUniqueOrThrow({ where: { id: ticket.id } })).status === 'DONE', 'repair completed');
    await ui.login('tenant'); await ui.go('/tenant/maintenance'); await ui.expect('Đã xong');
  });

  // PHẦN 12: Chủ trọ thêm khoản chi và xem báo cáo / sổ thu chi.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,expense --delay=2500
  await scenario('12-chi-phi-va-bao-cao', 'expense', async () => {
    await ui.login('landlord'); await ui.go('/expenses/form');
    await ui.field('Tiêu đề', 'DEMO mua bong den'); await ui.field('Số tiền (đ)', '50000');
    await ui.field('Ghi chú', 'Chi phi gia lap'); await ui.tap('Thêm chi phí');
    assert.ok(await waitUntil(() => prisma.expense.findFirst({ where: { title: 'DEMO mua bong den', landlordId: fixtures.landlordId } }), 'expense creation'));
    await ui.go('/expenses'); await ui.expect('DEMO mua bong den'); await ui.go('/reports');
  });

  // PHẦN 13: Gia hạn: người thuê yêu cầu → chủ trọ duyệt → thực hiện riêng.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,renewal --delay=2500
  await scenario('13-gia-han-hai-vai-tro', 'renewal', async () => {
    await openLifecycle('tenant'); await ui.tap('Gửi yêu cầu mới');
    await ui.field('Gia hạn đến ngày (YYYY-MM-DD)', fixtures.renewalDate);
    await ui.field('Lý do / ghi chú', 'DEMO muon gia han hop dong'); await ui.tap('Gửi yêu cầu');
    const before = await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } });
    await openLifecycle('landlord'); await ui.tap('Duyệt');
    await ui.field('Lý do xử lý', 'DEMO dong y gia han'); await ui.tap('Xác nhận');
    const afterReview = await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } });
    assert.equal(afterReview.endDate.toISOString(), before.endDate.toISOString(), 'Review must not execute renewal');
    await ui.tap('Thực hiện yêu cầu đã duyệt'); await ui.tap('Xác nhận'); await ui.expect('Đã thực hiện');
    const lease = await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } });
    assert.equal(lease.endDate.toISOString().slice(0, 10), fixtures.renewalDate);
    await openLifecycle('tenant'); await ui.expect('Đã thực hiện');
  });

  // PHẦN 14: Chủ trọ thêm/xóa người ở cùng; người thuê kiểm tra danh sách.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,occupants --delay=2500
  await scenario('14-nguoi-o-cung', 'occupants', async () => {
    await openLifecycle('landlord'); await ui.tap('Thêm người ở cùng');
    await ui.field('Họ và tên', 'Ban o cung DEMO'); await ui.tap('Xác nhận');
    await ui.expect('Ban o cung DEMO');
    await openLifecycle('tenant'); await ui.expect('Ban o cung DEMO');
    await openLifecycle('landlord'); await ui.tap('Xóa người ở cùng', 'Tooltip'); await ui.tap('Xác nhận');
    assert.equal(await prisma.tenantOccupant.count({ where: { leaseId: fixtures.leaseId, fullName: 'Ban o cung DEMO' } }), 0);
  });

  // PHẦN 15: Thông báo, tài khoản, hội thoại Zalo giả lập và trung tâm hỗ trợ.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,notifications --delay=2500
  await scenario('15-thong-bao-tai-khoan', 'notifications', async () => {
    for (const [role, paths] of [['tenant', ['/tenant/notifications', '/housing/notifications', '/explore/account', '/tenant/zalo']],
    ['landlord', ['/notifications', '/settings', '/settings/fake-zalo', '/support-center']]]) {
      await ui.login(role);
      for (const path of paths) { await ui.go(path); assert.ok((await ui.snapshot()).texts.length); }
    }
  }, ['login'], 'screen');

  // PHẦN 15B: Chủ trọ gửi ticket hỗ trợ, admin phản hồi và xác nhận tin đã lưu.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,support --delay=2500
  await scenario('15b-ticket-ho-tro', 'support', async () => {
    await ui.login('landlord'); await ui.go('/support-center'); await ui.tap('Tạo yêu cầu');
    await ui.field('Tiêu đề', 'DEMO can ho tro doi soat');
    await ui.field('Nội dung yêu cầu', 'DEMO ticket duoc tao tu giao dien, khong phai su co that');
    await ui.tap('Xác nhận');
    const ticket = await waitUntil(() => prisma.supportTicket.findFirst({ where: { requesterId: fixtures.landlordId, subject: 'DEMO can ho tro doi soat' } }), 'support ticket');
    await ui.login('admin'); await ui.go(`/admin/support-center?ticketId=${ticket.id}`);
    await ui.field('Nội dung phản hồi', 'DEMO admin da tiep nhan yeu cau ho tro'); await ui.tap('Gửi phản hồi');
    await waitUntil(() => prisma.supportMessage.findFirst({ where: { ticketId: ticket.id, authorId: fixtures.adminId, internal: false } }), 'admin public reply');
    await ui.login('landlord'); await ui.go(`/support-center?ticketId=${ticket.id}`);
    await ui.reveal(finder('Contains', 'DEMO admin da tiep nhan'));
    await ui.expect('DEMO admin da tiep nhan');
  });

  // PHẦN 15C: Đổi mật khẩu thật và đăng nhập lại, không sửa dữ liệu cá nhân.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,security --delay=2500
  await scenario('15c-doi-mat-khau', 'security', async () => {
    for (const role of ['tenant', 'landlord']) {
      await ui.login(role); await ui.go(role === 'tenant' ? '/tenant/password' : '/settings/password');
      await ui.field('Mật khẩu hiện tại', credentials[role].password);
      const next = `Changed-${randomBytes(10).toString('hex')}!a1`;
      await ui.field('Mật khẩu mới', next); await ui.tap('Đổi mật khẩu', 'ButtonText');
      await waitUntil(async () => (await ui.snapshot()).route.startsWith('/auth'), 'password change revokes session');
      credentials[role].password = next; ui.role = null; await ui.login(role);
    }
  });

  // PHẦN 15D: Chủ trọ thêm biểu phí riêng cho phòng đã tạo qua UI.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,room,room-services --delay=2500
  await scenario('15d-bieu-phi-phong', 'room-services', async () => {
    await ui.login('landlord'); await ui.go(`/rooms/${fixtures.createdRoomId}`); await ui.tap('Info');
    await ui.tap('Thêm phí', 'Tooltip');
    await ui.field('Tên dịch vụ', 'DEMO Wifi'); await ui.field('Đơn giá (VND)', '50000');
    await ui.field('Đơn vị tính', 'thang');
    await ui.field('Ghi chú / lý do thay đổi', 'DEMO them dich vu tu dong'); await ui.tap('Lưu biểu phí');
    await waitUntil(() => prisma.roomServiceFee.findFirst({ where: { roomId: fixtures.createdRoomId, name: 'DEMO Wifi' } }), 'service tariff');
    await ui.expect('DEMO Wifi');
  }, ['login', '04-tao-sua-phong']);

  // PHẦN 16: Duyệt route, không coi mở màn hình là đã thử mọi nút.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,screens --delay=2500
  // Đây là SCREEN SMOKE, không được báo thành kiểm thử mọi nút trên màn.
  if (options.sections.includes('screens')) {
    const listing = await prisma.roomListing.findUniqueOrThrow({ where: { id: fixtures.listingId } });
    if (listing.status !== 'PUBLISHED') {
      const smokeRoom = await prisma.room.create({ data: { propertyId: fixtures.propertyId, name: 'SCREEN-ONLY-C301', basePrice: 3200000, status: 'VACANT' } });
      const smokeListing = await prisma.roomListing.create({
        data: {
          roomId: smokeRoom.id, title: 'SCREEN ONLY - Fixture',
          description: 'Independent read-only smoke fixture.', city: 'Hồ Chí Minh', district: 'Thủ Đức',
          publicAddress: 'Dia chi DEMO', monthlyRent: 3200000, deposit: 3000000, areaSqm: 28, imageUrls: [], amenities: [], status: 'PUBLISHED', publishedAt: new Date()
        }
      });
      fixtures.listingId = smokeListing.id;
    }
    for (const role of ['tenant', 'landlord', 'admin']) await screenSweep(inventory.routes, role);
  }

  // PHẦN 17: Nhân viên: quyền xem khu/phòng, hóa đơn, bảo trì và nhật ký.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,staff --delay=2500
  await scenario('17-nhan-vien-theo-phan-quyen', 'staff', async () => {
    await ui.login('staff');
    for (const path of ['/dashboard', '/properties', `/rooms/${fixtures.roomId}`, '/billing', '/maintenance', '/audit']) {
      await ui.go(path); assert.equal((await ui.snapshot()).route.split('?')[0], path);
    }
    const rooms = await api(`properties/${fixtures.propertyId}/rooms`, 'staff');
    assert.ok(rooms.some(room => room.id === fixtures.roomId));
  }, ['login'], 'screen+API');

  // PHẦN 17B: Chủ trọ mời nhân viên và kiểm tra phạm vi được cấp.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,staff --delay=2500
  await scenario('17b-moi-nhan-vien', 'staff', async () => {
    await ui.login('landlord'); await ui.go('/staff'); await ui.tap('Mời nhân viên', 'Tooltip');
    const email = `invite.${randomBytes(5).toString('hex')}@example.test`;
    await ui.field('Họ tên', 'Nhan vien moi DEMO'); await ui.field('Email', email);
    await ui.field('Số điện thoại', '0900000007'); await ui.tap('Khu tro KIEM THU'); await ui.tap('Tạo mã');
    const invitation = await waitUntil(() => prisma.staffInvite.findFirst({ where: { email, landlordId: fixtures.landlordId } }), 'staff invitation');
    assert.ok(invitation.propertyIds.includes(fixtures.propertyId)); assert.equal(invitation.acceptedAt, null);
    await ui.tap('Đóng'); await ui.tap('Phạm vi / Kiểm tra quyền'); await ui.expect('Phạm vi nhân viên');
  });

  // PHẦN 18: Mở các phân hệ quản trị theo đúng phiên admin.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,admin --delay=2500
  await scenario('18-admin-quan-tri', 'admin', async () => {
    await ui.login('admin');
    for (const path of ['/admin/search', '/admin/accounts', '/admin/moderation', '/admin/operations', '/admin/security', '/admin/audit-logs']) {
      await ui.go(path); assert.equal((await ui.snapshot()).route.split('?')[0], path);
    }
  }, ['login'], 'screen');

  // PHẦN 19: Yêu cầu → duyệt riêng → xem trước → quyết toán → ghi sổ hoàn cọc.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=login,deposit,checkout --delay=2500
  await scenario('19-yeu-cau-tra-phong', 'checkout', async () => {
    await openLifecycle('tenant'); await ui.tap('Gửi yêu cầu mới');
    await ui.tap('Gia hạn'); await ui.tap('Trả phòng');
    const today = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }).format(new Date());
    await ui.field('Ngày dự kiến (YYYY-MM-DD)', today);
    await ui.field('Lý do / ghi chú', 'DEMO tra phong, chua xac nhan quyet toan'); await ui.tap('Gửi yêu cầu');
    await ui.expect('Chờ duyệt');
    assert.equal((await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } })).status, 'ACTIVE');
    await openLifecycle('landlord'); await ui.tap('Duyệt');
    await ui.field('Lý do xử lý', 'DEMO tiep nhan yeu cau tra phong'); await ui.tap('Xác nhận');
    assert.equal((await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } })).status, 'ACTIVE');
    await ui.tap('Mở quyết toán hiện có');
    await ui.field('Lý do, tình trạng phòng và giải thích chi phí', 'DEMO quyet toan, khong thuc hien chuyen tien that');
    await ui.tap('Xem trước quyết toán');
    assert.equal(await prisma.leaseSettlement.count({ where: { leaseId: fixtures.leaseId } }), 0, 'Preview must not end lease.');
    await ui.tap('Xác nhận trả phòng'); await ui.tap('Xác nhận trả phòng', 'Text', -1);
    const settlement = await waitUntil(() => prisma.leaseSettlement.findUnique({ where: { leaseId: fixtures.leaseId } }), 'checkout settlement');
    assert.equal((await prisma.lease.findUniqueOrThrow({ where: { id: fixtures.leaseId } })).status, 'ENDED');
    if (settlement.refundAmount > 0) {
      await ui.tap('Ghi nhận đã hoàn cọc');
      await ui.field('Mã chuyển khoản / biên nhận', 'DEMO-RECEIPT-NO-REAL-MONEY');
      await ui.field('Ghi chú xác nhận', 'DEMO chi ghi so thu nghiem khong chuyen tien that');
      await ui.tap('Ghi nhận');
      await waitUntil(async () => (await prisma.leaseSettlement.findUniqueOrThrow({ where: { leaseId: fixtures.leaseId } })).refundStatus === 'PAID', 'deposit refund ledger');
    }
  });

  // PHẦN 20: Toàn bộ Flutter tests, backend unit tests và API E2E.
  // Chạy riêng: npm --prefix test/system_demo run demo -- --sections=regression
  // Chạy sau demo, trên DB riêng cho TỪNG suite; lưu từng log vào báo cáo.
}

async function regressionSuites(inventory, sourceUrl, flutter) {
  if (!options.sections.includes('regression')) return;
  await runCase(results, 'regression:flutter-all', 'regression', [], async result => {
    try { result.output = await command(flutter, ['test'], { env: { ...process.env }, includeStderr: true }); }
    catch (error) { result.output = error.output ?? error.message; throw error; }
    finally { await writeFile(join(output, 'flutter-tests.log'), result.output ?? 'See failed result.'); }
  });
  await runCase(results, 'regression:backend-unit', 'regression', [], async result => {
    try { result.output = await command('npm', ['test', '--', '--runInBand'], { cwd: backend, env: { ...process.env }, includeStderr: true }); }
    catch (error) { result.output = error.output ?? error.message; throw error; }
    finally { await writeFile(join(output, 'backend-unit.log'), result.output); }
  });
  await runCase(results, 'regression:safety-scripts', 'regression', [], async result => {
    try {
      result.output = await command('node', ['--test', ...inventory.scriptSuites.map(name => `scripts/${name}`)], {
        cwd: backend, env: { ...process.env }, includeStderr: true,
      });
    } catch (error) { result.output = error.output ?? error.message; throw error; }
    finally { await writeFile(join(output, 'safety-scripts.log'), result.output); }
  });
  for (const suite of inventory.apiSuites) {
    if (interrupted) break;
    console.log(`Regression: ${suite}`);
    const family = suite === 'app-functional.e2e-spec.ts' ? 'functional' : suite === 'lease-settlement.e2e-spec.ts' ? 'settlement'
      : /^(admin-(accounts|registry|inventory)|manual-transfers)/.test(suite) ? 'admin_accounts'
        : /^(billing-production|invoice-tariffs|staff-lifecycle)/.test(suite) ? 'billing'
          : suite === 'maintenance-audit.e2e-spec.ts' ? 'repairs' : suite === 'chatbot.e2e-spec.ts' ? 'chatbot' : 'ui';
    const target = databaseForRun(sourceUrl, String(Date.now()), randomBytes(6).toString('hex'), family);
    const name = new URL(target).pathname.slice(1);
    let created = false;
    await runCase(results, `regression:api:${suite}`, 'regression', [], async result => {
      try {
        await sql(sourceUrl, `CREATE DATABASE "${name}"`); created = true;
        const env = { ...testEnv, DATABASE_URL: target };
        if (suite === 'app-functional.e2e-spec.ts') Object.assign(env, {
          AUTH_PUBLIC_APP_URL: 'https://app.example.test', AUTH_DELIVERY_WEBHOOK_URL: 'https://delivery.example.test',
        });
        await command('npx', ['prisma', 'migrate', 'deploy'], { cwd: backend, env });
        result.output = await command('npm', ['run', 'test:e2e', '--', '--runTestsByPath', `test/e2e/${suite}`, '--runInBand'], { cwd: backend, env, includeStderr: true });
      } catch (error) {
        result.output = error.output ?? error.message;
        throw error;
      } finally {
        await writeFile(join(output, `${suite}.log`), result.output ?? 'No test output.');
        if (created) await sql(sourceUrl, `DROP DATABASE "${name}" WITH (FORCE)`);
      }
    });
  }
}

async function main() {
  const onSignal = () => {
    interrupted = true;
    for (const child of children) stopOwned(child);
  };
  process.once('SIGINT', onSignal);
  process.once('SIGTERM', onSignal);
  options = parseOptions(process.argv.slice(2));
  const runId = `${Date.now()}_${randomBytes(6).toString('hex')}`;
  output = join(root, 'output/system-demo', runId);
  await mkdir(output, { recursive: true });
  const inventory = await buildInventory();
  await writeFile(join(output, 'coverage-inventory.json'), JSON.stringify(inventory, null, 2));
  if (options.inventory) {
    console.log(`${inventory.routes.length} registered routes; ${inventory.actions.length} action labels; ${inventory.apiSuites.length} API suites; ${inventory.widgetSuites.length} Flutter suites.\n${output}/coverage-inventory.json`);
    return;
  }
  const flutter = process.env.FLUTTER_BIN || 'flutter';
  const fileEnv = await readFile(join(backend, '.env'), 'utf8').then(parseEnv).catch(error => {
    if (error.code === 'ENOENT') return {};
    throw error;
  });
  const sourceEnv = { ...fileEnv, ...process.env };
  const sourceUrl = sourceEnv.DATABASE_URL;
  assertLocalDatabase(sourceUrl);
  const target = databaseForRun(sourceUrl, runId.split('_')[0], runId.split('_')[1]);
  const databaseName = new URL(target).pathname.slice(1);
  const apiPort = await freePort();
  const appiumPort = await freePort();
  testEnv = {
    ...process.env, NODE_ENV: 'test', DATABASE_URL: target, PORT: String(apiPort),
    JWT_ACCESS_SECRET: randomBytes(32).toString('hex'), JWT_REFRESH_SECRET: randomBytes(32).toString('hex'),
    DELIVERY_ENCRYPTION_KEY: randomBytes(32).toString('base64'), UPLOADS_DIR: join(output, 'uploads'),
    AUTH_PUBLIC_APP_URL: 'http://127.0.0.1', AUTH_DELIVERY_WEBHOOK_URL: '',
    ZALO_ZNS_ENABLED: 'false', NOTIFICATION_DELIVERY_ENABLED: 'false', CHATBOT_ENABLED: 'false', DEMO_PAYMENTS_ENABLED: 'false',
    OPERATIONS_SCHEDULER_ENABLED: 'false', SUPPORT_SCAN_WEBHOOK_URL: '', REPORT_STORAGE_URL: ''
  };
  for (const name of ['BILLING_OUTBOX', 'BILLING_AUTOMATION', 'OPERATIONS_SCHEDULER', 'SUPPORT_SLA', 'DELIVERY', 'ADMIN_REPORT', 'OPERATIONS_MONITOR', 'VIEWING_REMINDER', 'MAINTENANCE_SLA']) testEnv[`${name}_WORKER_ENABLED`] = 'false';
  apiBase = `http://127.0.0.1:${apiPort}/api/v1`;
  let created = false;
  let driver;
  let server;
  let appium;
  let flutterProcess;
  try {
    await sql(sourceUrl, `CREATE DATABASE "${databaseName}"`); created = true;
    console.log(`Disposable database: ${databaseName}\nOutput: ${output}`);
    await command('npx', ['prisma', 'migrate', 'deploy'], { cwd: backend });
    await command('npx', ['prisma', 'migrate', 'diff', '--from-schema-datasource', 'prisma/schema.prisma', '--to-schema-datamodel', 'prisma/schema.prisma', '--exit-code'], { cwd: backend });
    await command('npm', ['run', 'build'], { cwd: backend });
    server = start('node', ['dist/src/main.js'], { cwd: backend });
    await waitUntil(async () => (await fetch(`${apiBase}/health/ready`)).ok, 'isolated API', 60000);
    await initializeFixtures();
    if (options.sections.some(section => section !== 'regression')) {
      const simulators = JSON.parse(await command('xcrun', ['simctl', 'list', 'devices', 'available', '--json']));
      let device = options.device || Object.values(simulators.devices).flat().find(item => item.name === 'Rental System Demo')?.udid;
      if (!device) {
        const runtimes = JSON.parse(await command('xcrun', ['simctl', 'list', 'runtimes', '--json']));
        const runtime = runtimes.runtimes.find(item => item.isAvailable && item.name.startsWith('iOS'));
        assert.ok(runtime, 'An installed iOS simulator runtime is required.');
        device = (await command('xcrun', ['simctl', 'create', 'Rental System Demo', 'com.apple.CoreSimulator.SimDeviceType.iPhone-16', runtime.identifier])).trim();
      }
      simulatorId = device;
      await command('open', ['-a', 'Simulator', '--args', '-CurrentDeviceUDID', device]);
      await command('xcrun', ['simctl', 'boot', device]).catch(async error => {
        const booted = JSON.parse(await command('xcrun', ['simctl', 'list', 'devices', 'booted', '--json']));
        if (!Object.values(booted.devices).flat().some(item => item.udid === device)) throw error;
      });
      await command('xcrun', ['simctl', 'bootstatus', device, '-b']);
      await command(flutter, ['pub', 'get']);
      flutterProcess = start(flutter, ['run', '-d', device, '-t', 'test/system_demo/appium_main.dart', '--disable-dds',
        '--dart-define=SYSTEM_DEMO=true', `--dart-define=API_BASE_URL=${apiBase}`]);
      const vmUrl = await waitUntil(() => {
        if (flutterProcess.startError || flutterProcess.exitCode !== null) throw new Error(flutterProcess.output.slice(-5000));
        return flutterProcess.output.match(/A Dart VM Service.*?(http:\/\/[^\s]+)/)?.[1];
      }, 'Flutter test build / VM Service', 240000);
      const appiumEnv = { ...testEnv, APPIUM_HOME: join(here, '.appium') };
      const appiumBin = join(here, 'node_modules/.bin/appium');
      await command(appiumBin, ['driver', 'install', '--source=npm', 'appium-flutter-driver@4.1.0'], { env: appiumEnv }).catch(async error => {
        const listed = await command(appiumBin, ['driver', 'list', '--installed', '--json'], { env: appiumEnv });
        if (!JSON.parse(listed).flutter) throw error;
      });
      appium = start(appiumBin, ['--address', '127.0.0.1', '--port', String(appiumPort), '--log-level', 'warn', '--log', join(output, 'appium.log')], { env: appiumEnv });
      await waitUntil(async () => (await fetch(`http://127.0.0.1:${appiumPort}/status`)).ok, 'Appium', 30000);
      const { remote } = await import('webdriverio');
      driver = await remote({
        hostname: '127.0.0.1', port: appiumPort, logLevel: 'error', connectionRetryCount: 0, connectionRetryTimeout: 180000,
        capabilities: {
          platformName: 'iOS', 'appium:automationName': 'Flutter', 'appium:udid': device,
          'appium:bundleId': 'com.example.rentalRoomManagement', 'appium:noReset': true, 'appium:autoLaunch': false,
          'appium:observatoryWsUri': vmUrl.replace('http:', 'ws:').replace(/\/$/, '') + '/ws',
          'appium:newCommandTimeout': 180, 'appium:wdaLocalPort': await freePort()
        }
      });
      ui = new DemoUI(driver);
      await driver.execute('flutter:setFrameSync', false, 5000);
      assert.equal((await ui.snapshot()).apiBaseUrl, apiBase, 'Never drive an app connected to the personal backend.');
      await visualJourneys(inventory);
      await driver.deleteSession(); driver = null;
    }
    for (const child of [flutterProcess, appium, server]) stopOwned(child);
    await prisma.$disconnect(); prisma = null;
    if (!interrupted) await regressionSuites(inventory, sourceUrl, flutter);
  } catch (error) {
    results.push({ id: 'infrastructure', layer: 'infrastructure', status: 'failed', error: error.stack ?? String(error) });
    console.error(error.message);
  } finally {
    if (interrupted) results.push({ id: 'interrupted', layer: 'infrastructure', status: 'failed', error: 'Stopped by SIGINT/SIGTERM.' });
    if (driver) await driver.deleteSession().catch(() => { });
    if (prisma) await prisma.$disconnect();
    for (const child of children) stopOwned(child);
    if (flutterProcess) await writeFile(join(output, 'flutter-run.log'), flutterProcess.output);
    if (server) await writeFile(join(output, 'backend.log'), server.output);
    if (appium) await writeFile(join(output, 'appium-process.log'), appium.output);
    if (ui) await writeFile(join(output, 'steps.json'), JSON.stringify(ui.steps, null, 2));
    await writeFile(join(output, 'coverage.json'), JSON.stringify({
      allFunctionsVerified: false,
      routeSmoke: inventory.routes.map(route => ({
        ...route,
        checks: results.filter(result => result.id.endsWith(`:${route.path}`)).map(({ id, status }) => ({ id, status })),
      })),
      actions: inventory.actions.map(action => ({
        ...action,
        labelObserved: ui?.steps.some(step => step.text === `Bấm: ${action.text}`) ?? false,
        warning: 'Observed labels are not unique selectors or proof that this source action passed.',
      })),
      pendingCoverage,
    }, null, 2));
    if (created && !options.keepDatabase) {
      assert.match(databaseName, /^rental_ui_test_\d+_[a-f0-9]{12}$/);
      try { await sql(sourceUrl, `DROP DATABASE "${databaseName}" WITH (FORCE)`); }
      catch (error) { results.push({ id: 'cleanup:database', layer: 'infrastructure', status: 'failed', error: error.message }); }
    }
    const report = await writeReport(output, results, { runId, routes: inventory.routes, selectedSections: options.sections, pendingCoverage });
    console.log(`\nReport: ${output}/report.html\n${report.success ? 'Selected checks passed' : 'Failed / blocked / unverified checks remain'}`);
    process.exitCode = report.success ? 0 : 1;
    process.removeListener('SIGINT', onSignal);
    process.removeListener('SIGTERM', onSignal);
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}

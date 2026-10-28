const origin = (() => {
  let url;
  try { url = new URL(process.env.STAGING_API_URL ?? ''); } catch {}
  const local = url?.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) && !!url.port;
  if (!url || (url.protocol !== 'https:' && !local) || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('Set STAGING_API_URL to an HTTPS API origin (or local test server), without credentials or a path.');
  }
  return url;
})();
const tokens = { admin: process.env.STAGING_ADMIN_TOKEN, support: process.env.STAGING_SUPPORT_TOKEN, landlord: process.env.STAGING_LANDLORD_TOKEN };
if (Object.values(tokens).some(token => !token)) throw new Error('Provide dedicated staging ADMIN, SUPPORT and LANDLORD tokens. Do not use production credentials.');
const checks = [
  ['/health/live', undefined, 200], ['/health/ready', undefined, 200],
  ['/admin/operations/health', undefined, 401], ['/admin/operations/health', 'landlord', 403],
  ['/admin/operations/health', 'support', 403], ['/admin/operations/health', 'admin', 200],
  ['/admin/audit-logs', 'support', 403], ['/admin/audit-logs', 'admin', 200],
  ['/admin/audit-logs?from=not-a-date', 'admin', 400],
  ['/notification-center/preferences', 'support', 200],
  ['/notification-center/preferences', 'landlord', 200],
  ['/admin/finance/statement-lines', 'support', 403],
  ['/admin/finance/statement-lines', 'landlord', 403],
  ['/admin/finance/statement-lines', 'admin', 200],
  ['/admin/operations/notification-delivery', 'support', 403],
  ['/admin/operations/notification-delivery', 'admin', 200],
];
let failed = false;
for (const [path, role, expected] of checks) {
  try {
    const response = await fetch(new URL(`/api/v1${path}`, origin), {
      headers: role ? { authorization: `Bearer ${tokens[role]}` } : {}, redirect: 'error', signal: AbortSignal.timeout(10000),
    });
    const noStore = !path.startsWith('/admin/') || /no-store/.test(response.headers.get('cache-control') ?? '') || expected !== 200;
    const ok = response.status === expected && noStore && !!response.headers.get('x-request-id');
    await response.body?.cancel();
    console.log(`${ok ? 'PASS' : 'FAIL'} ${role ?? 'anonymous'} ${path} expected=${expected} actual=${response.status}`);
    failed ||= !ok;
  } catch { console.log(`FAIL ${role ?? 'anonymous'} ${path}: network/timeout`); failed = true; }
}
process.exitCode = failed ? 1 : 0;

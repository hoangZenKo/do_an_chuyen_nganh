import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const hours = Number(process.env.BACKUP_INTERVAL_HOURS || 24);
if (!Number.isFinite(hours) || hours < 1 || hours > 168) throw new Error('BACKUP_INTERVAL_HOURS must be between 1 and 168.');
let stopping = false;
let child;
let timer;
function run() {
  if (stopping) return;
  child = spawn(process.execPath, [fileURLToPath(new URL('./database-safety.mjs', import.meta.url)), 'backup'], { stdio: 'inherit', env: process.env });
  child.once('error', () => { console.error('Backup process could not start.'); });
  child.once('close', code => {
    if (code !== 0) console.error('BACKUP_FAILED: investigate with the production runbook.');
    if (!stopping) timer = setTimeout(run, hours * 3600000);
  });
}
function stop() { stopping = true; if (timer) clearTimeout(timer); child?.kill('SIGTERM'); }
process.once('SIGTERM', stop); process.once('SIGINT', stop);
run();

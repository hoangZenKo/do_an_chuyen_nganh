const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');
const directory = path.resolve(__dirname, '..');
const root = path.resolve(directory, '../..');
const catalog = JSON.parse(fs.readFileSync(path.join(directory, 'data/catalog.json'), 'utf8'));
const trace = JSON.parse(fs.readFileSync(path.join(directory, 'data/traceability.json'), 'utf8'));
const failures = [];
const checks = {};
function check(name, condition, detail) {
  checks[name] = { passed: Boolean(condition), detail };
  if (!condition) failures.push(name);
}
const useCases = catalog.useCases;
const ids = new Set(useCases.map(item => item.id));
const actorIds = new Set(catalog.actors.map(item => item.id));
const externalIds = new Set(catalog.externalActors.map(item => item.id));
const groupIds = new Set(catalog.groups.map(item => item.id));
const technicalIds = new Set(trace.technical.map(item => item.id));
const validTarget = identifier => ids.has(identifier) || technicalIds.has(identifier);
check('unique_162_uc_ids', ids.size === 162 && useCases.length === ids.size, useCases.length);
check('sixteen_business_groups', groupIds.size === 16 && catalog.groups.reduce((total, group) => total + group.ucCount, 0) === 162, catalog.groups.map(group => [group.id, group.ucCount]));
check('five_primary_five_external_actors', actorIds.size === 5 && externalIds.size === 5, [actorIds.size, externalIds.size]);
check('mandatory_catalog_fields', useCases.every(item => item.id && item.title && item.goal && item.status && groupIds.has(item.businessGroup) && item.primaryActorIds.length && item.primaryActorIds.every(actor => actorIds.has(actor)) && item.supportingActorIds.every(actor => externalIds.has(actor))), 'Business goals and actual actors required');
check('matrix_same_uc_and_actor_set', useCases.every(item => Object.keys(item.matrix).length === actorIds.size && [...actorIds].every(actor => typeof item.matrix[actor] === 'string' && item.matrix[actor].length)), useCases.length);
const leaves = Object.values(catalog.functions).flatMap(functions => functions.flatMap(item => item[1]));
check('fdd_exact_uc_coverage', leaves.length === 162 && new Set(leaves).size === 162 && leaves.every(identifier => ids.has(identifier)), leaves.length);
check('fdd_business_group_alignment', catalog.groups.every(group => catalog.functions[group.id].flatMap(item => item[1]).every(identifier => useCases.find(item => item.id === identifier).businessGroup === group.id)), 'Each UC exactly one business group');
check('trace_records_same_uc_set', trace.useCases.length === 162 && new Set(trace.useCases.map(item => item.id)).size === 162 && trace.useCases.every(item => ids.has(item.id) && (item.services.length || item.localEvidence.length)), trace.useCases.length);
check('405_unique_endpoints_disposition', trace.routes.length === 405 && new Set(trace.routes.map(item => item.binding)).size === 405 && trace.routes.every(item => item.ucs.length + item.technical.length > 0 && item.ucs.every(identifier => ids.has(identifier)) && item.technical.every(identifier => technicalIds.has(identifier))), trace.routes.length);
check('395_uc_10_technical_endpoints', trace.routes.filter(item => item.ucs.length).length === 395 && trace.routes.filter(item => item.technical.length).length === 10 && trace.routes.every(item => !(item.ucs.length && item.technical.length)), [trace.routes.filter(item => item.ucs.length).length, trace.routes.filter(item => item.technical.length).length]);
check('all_bindings_linked_to_route_or_local_logic', useCases.every(item => item.bindings.every(binding => binding.startsWith('LOCAL.') || trace.routes.some(route => route.binding === binding && route.ucs.includes(item.id)))), 'No missing controller binding');
check('180_survey_items_disposition', trace.features.length === 180 && new Set(trace.features.map(item => item.id)).size === 180 && trace.features.every(item => item.ucs.length + item.technical.length + item.gaps.length > 0 && item.ucs.every(identifier => ids.has(identifier))), trace.features.length);
check('164_prior_ids_crosswalk', trace.crosswalk.length === 164 && new Set(trace.crosswalk.map(item => item.old)).size === 164 && trace.crosswalk.every(item => item.targets.length && item.targets.every(validTarget)), trace.crosswalk.length);
check('63_historical_ids_crosswalk', trace.legacyCrosswalk.length === 63 && trace.legacyCrosswalk.every(item => item.targets.length && item.targets.every(validTarget)), trace.legacyCrosswalk.length);
const oldIds = new Set(trace.crosswalk.map(item => item.old));
check('id_balance_164_minus17_plus15', useCases.filter(item => oldIds.has(item.id)).length === 147 && useCases.filter(item => !oldIds.has(item.id)).length === 15 && trace.crosswalk.filter(item => !ids.has(item.old)).length === 17, '164 - 17 + 15 = 162');
check('decisions_resolve_to_valid_targets', trace.decisions.every(item => item.targets.length && item.targets.every(validTarget)), trace.decisions.length);
const states = useCases.reduce((result, item) => { result[item.status] = (result[item.status] || 0) + 1; return result; }, {});
check('verification_states', states['Xác minh tĩnh'] === 151 && states['Một phần'] === 9 && states['Đã triển khai — DEMO'] === 1 && states['Đã triển khai — MÔ PHỎNG'] === 1, states);
check('three_unverified_not_uc', trace.unverified.length === 3 && trace.unverified.every(item => !ids.has(item.id)), trace.unverified.map(item => item.id));
const hasStaff = identifier => useCases.find(item => item.id === identifier).primaryActorIds.includes('A03');
check('staff_sensitive_role_boundaries', !hasStaff('UC-OPT-09') && !hasStaff('UC-BIL-16') && !hasStaff('UC-BIL-22') && !hasStaff('UC-TNT-03') && hasStaff('UC-TNT-03.1') && hasStaff('UC-STF-04'), 'No inferred fee-write/tariff-approve/period-lock/invite rights; direct tenant account and staff lookup retained');
check('staff_primary_has_allowed_handler', useCases.filter(item => item.primaryActorIds.includes('A03') && !item.id.startsWith('UC-SYS-')).every(item => trace.useCases.find(record => record.id === item.id).handlers.some(handler => handler.roles.includes('AuthRole.STAFF') && handler.staffAllowedAfterInterceptor)), 'Role + interceptor, not decorators alone');
check('lease_creation_not_duplicated', !ids.has('UC-DIS-11') && useCases.find(item => item.id === 'UC-TNT-05').bindings.includes('HousingController.lease'), 'Direct/viewing variants consolidated');
check('tenant_lease_pdf_not_inferred', !useCases.find(item => item.id === 'UC-TEN-02').bindings.includes('LOCAL.leasePdf'), 'No portal lease PDF link found');
const changedSources = [];
for (const [relative, expected] of Object.entries(trace.sourceHashes)) {
  const absolute = path.join(root, relative);
  if (!fs.existsSync(absolute) || crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex') !== expected) changedSources.push(relative);
}
check('846_source_hashes_unchanged', Object.keys(trace.sourceHashes).length === 846 && !changedSources.length, changedSources);
const invalidEvidence = [];
for (const item of trace.evidenceReferences) {
  const absolute = path.join(root, item.file);
  if (!fs.existsSync(absolute)) { invalidEvidence.push(item); continue; }
  const lines = fs.readFileSync(absolute, 'utf8').split('\n');
  if (!Number.isInteger(item.line) || item.line < 1 || item.line > lines.length) invalidEvidence.push(item);
}
check('all_evidence_file_line_anchors_exist', !invalidEvidence.length, { checked: trace.evidenceReferences.length, invalid: invalidEvidence });
const catalogMarkdown = fs.readFileSync(path.join(directory, '05_Use_Case_Catalog.md'), 'utf8');
const matrixMarkdown = fs.readFileSync(path.join(directory, '04_Actor_Use_Case_Matrix.md'), 'utf8').split('## 2. Những điều kiện service')[0];
function tableIds(text) {
  return text.split('\n').filter(line => line.startsWith('| UC-')).map(line => line.split('|')[1].trim());
}
check('markdown_catalog_162_rows', tableIds(catalogMarkdown).length === 162 && tableIds(catalogMarkdown).every(identifier => ids.has(identifier)), tableIds(catalogMarkdown).length);
check('markdown_matrix_162_rows', tableIds(matrixMarkdown).length === 162 && tableIds(matrixMarkdown).every(identifier => ids.has(identifier)), tableIds(matrixMarkdown).length);
const fullFdd = fs.readFileSync(path.join(directory, '02_FDD.puml'), 'utf8');
const fullLeaves = fullFdd.split('\n').filter(line => line.startsWith('**** UC-')).map(line => line.slice(5).split(' ')[0]);
check('plantuml_wbs_not_uc_diagram', fullFdd.startsWith('@startwbs') && fullFdd.trim().endsWith('@endwbs') && !/^\s*(actor|usecase|@startuml)\b/m.test(fullFdd) && fullLeaves.length === 162 && fullLeaves.every(identifier => ids.has(identifier)), fullLeaves.length);
const svgPaths = [path.join(directory, '02_FDD.svg')];
for (const group of catalog.groups) {
  const text = fs.readFileSync(path.join(directory, 'diagrams', group.id + '_FDD.puml'), 'utf8');
  const count = text.split('\n').filter(line => line.startsWith('**** UC-')).length;
  check('group_fdd_' + group.id, count === group.ucCount && text.startsWith('@startwbs') && text.trim().endsWith('@endwbs'), count);
  svgPaths.push(path.join(directory, 'diagrams', group.id + '_FDD.svg'));
}
try {
  childProcess.execFileSync('python3', ['-c', 'import sys, xml.etree.ElementTree as ET; [ET.parse(p) for p in sys.argv[1:]]', ...svgPaths], { stdio: 'pipe' });
  check('17_svg_valid_xml', true, svgPaths.length);
} catch (error) { check('17_svg_valid_xml', false, String(error)); }
const placeholders = [];
for (const name of fs.readdirSync(directory).filter(name => name.endsWith('.md'))) {
  if (/\b(TODO|TBD|FIXME)\b/.test(fs.readFileSync(path.join(directory, name), 'utf8'))) placeholders.push(name);
}
check('no_unresolved_placeholders', !placeholders.length, placeholders);
const result = { status: failures.length ? 'FAILED' : 'PASSED', checkedAt: new Date().toISOString(), repositoryRoot: root, snapshotCommit: trace.snapshotCommit, applicationTestsRun: false, checks, failures };
fs.writeFileSync(path.join(directory, 'Validation_Result.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ status: result.status, checks: Object.keys(checks).length, failures, useCases: useCases.length, groups: catalog.groups.length, states, changedSources }, null, 2));
process.exitCode = failures.length ? 1 : 0;

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');
const directory = path.resolve(__dirname, '..');
const root = path.resolve(directory, '../..');
const baselineDirectory = path.join(root, 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog');
const catalog = JSON.parse(fs.readFileSync(path.join(baselineDirectory, 'data/catalog.json'), 'utf8'));
const trace = JSON.parse(fs.readFileSync(path.join(baselineDirectory, 'data/traceability.json'), 'utf8'));
const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'data/diagram-manifest.json'), 'utf8'));
const byId = new Map(catalog.useCases.map(item => [item.id, item]));
const actorIds = new Set([...catalog.actors, ...catalog.externalActors].map(item => item.id));
const failures = [];
const checks = [];
const check = (name, passed, detail) => { checks.push({ name, passed: Boolean(passed), detail }); if (!passed) failures.push(name); };
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
check('catalog_snapshot_unchanged', manifest.catalogSha256 === hash(path.join(baselineDirectory, 'data/catalog.json')), manifest.catalogSha256);
check('trace_snapshot_unchanged', manifest.traceabilitySha256 === hash(path.join(baselineDirectory, 'data/traceability.json')), manifest.traceabilitySha256);
check('commit_unchanged', childProcess.execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim() === manifest.snapshotCommit, manifest.snapshotCommit);
const changedSources = Object.entries(trace.sourceHashes).filter(([file, expected]) => !fs.existsSync(path.join(root, file)) || hash(path.join(root, file)) !== expected).map(([file]) => file);
check('846_source_hashes_unchanged', Object.keys(trace.sourceHashes).length === 846 && changedSources.length === 0, changedSources);
const details = manifest.diagrams.filter(item => item.kind === 'module');
const detailedIds = details.flatMap(item => item.ucIds);
check('162_detailed_uc_once', detailedIds.length === 162 && new Set(detailedIds).size === 162 && detailedIds.every(id => byId.has(id)), detailedIds.length);
check('16_groups_complete', catalog.groups.every(group => { const actual = detailedIds.filter(id => byId.get(id).businessGroup === group.id); return actual.length === group.ucCount; }), catalog.groups.map(group => [group.id, group.ucCount]));
check('module_group_preserved', details.every(diagram => diagram.ucIds.every(id => byId.get(id).businessGroup === diagram.groupId)), details.length);
check('21_module_pages', details.length === 21, details.length);
const overview = manifest.diagrams.find(item => item.kind === 'overall');
check('overall_real_12_ucs_all_five_actors', overview.ucIds.length === 12 && overview.ucIds.every(id => byId.has(id)) && catalog.actors.every(actor => overview.actorIds.includes(actor.id)), overview.actorIds);
check('no_unknown_actor', manifest.diagrams.every(diagram => diagram.actorIds.every(id => actorIds.has(id))), [...actorIds]);
check('no_uc_relationships_in_manifest', manifest.diagrams.every(diagram => diagram.relationships.length === 0), 'Include/extend/generalization intentionally absent; documented semantic decision.');
const staff = manifest.diagrams.filter(item => item.kind === 'actor');
const staffPrimary = staff.flatMap(diagram => diagram.associations.filter(edge => edge.kind === 'primary').map(edge => edge.ucId));
const catalogStaff = catalog.useCases.filter(item => item.primaryActorIds.includes('A03')).map(item => item.id);
check('staff_all_57_primary_once', staff.length === 6 && staffPrimary.length === 57 && new Set(staffPrimary).size === 57 && catalogStaff.every(id => staffPrimary.includes(id)), staffPrimary.length);
check('staff_all_three_readonly_once', ['UC-STF-01', 'UC-OPT-09', 'UC-BIL-16'].every(id => staff.flatMap(diagram => diagram.associations).filter(edge => edge.ucId === id && edge.kind === 'limited').length === 1), 'Only 3 limited variants in A03 views');
const alias = id => id.replaceAll('-', '_').replaceAll('.', '_');
for (const diagram of manifest.diagrams) {
  const file = path.join(directory, diagram.file);
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split('\n');
  const boundaryStart = lines.findIndex(line => line === 'rectangle "Hệ thống quản lý nhà trọ" as SYSTEM {');
  const boundaryEnd = lines.findIndex((line, index) => index > boundaryStart && line === '}');
  const parsedUcs = [...text.matchAll(/^  usecase "([^"\n]+)" as (\w+)([^\n]*)$/gm)];
  const parsedActors = [...text.matchAll(/^actor "([^"\n]+)" as ([AE]\d{2})$/gm)];
  const parsedEdges = [...text.matchAll(/^(\w+) (?:--|-\[#[A-Fa-f0-9]+\]-) (\w+)(?: : ([^\n]+))?$/gm)];
  check(diagram.id + ':standalone_boundary', text.startsWith('@startuml\n') && text.trim().endsWith('@enduml') && !/^!include/m.test(text) && boundaryStart > 0 && boundaryEnd > boundaryStart, diagram.file);
  check(diagram.id + ':actors_outside_ellipses_inside', lines.every((line, index) => !line.trim().startsWith('actor ') || index < boundaryStart || index > boundaryEnd) && lines.every((line, index) => !line.trim().startsWith('usecase ') || index > boundaryStart && index < boundaryEnd), diagram.file);
  check(diagram.id + ':exact_ids_names', parsedUcs.length === diagram.ucIds.length && new Set(parsedUcs.map(match => match[2])).size === parsedUcs.length && parsedUcs.every(match => { const [id, ...title] = match[1].split('\\n'); const source = byId.get(id); return source && diagram.ucIds.includes(id) && match[2] === alias(id) && title.join(' ').replace(/\s+/g, ' ').trim() === source.title; }), parsedUcs.length);
  check(diagram.id + ':actor_declarations', parsedActors.length === diagram.actorIds.length && new Set(parsedActors.map(match => match[2])).size === parsedActors.length && parsedActors.every(match => diagram.actorIds.includes(match[2]) && match[1].split('\\n').slice(1).join(' ').replace(/ \(có điều kiện\)$/, '') === [...catalog.actors, ...catalog.externalActors].find(actor => actor.id === match[2]).name), parsedActors.map(match => match[2]));
  check(diagram.id + ':associations_match_source', parsedEdges.length === diagram.associations.length && diagram.associations.every(edge => parsedEdges.filter(match => edge.kind === 'supporting' ? match[1] === alias(edge.ucId) && match[2] === edge.actorId && (match[3] || '') === edge.label : ((match[1] === edge.actorId && match[2] === alias(edge.ucId)) || (match[2] === edge.actorId && match[1] === alias(edge.ucId))) && (match[3] || '') === edge.label).length === 1), parsedEdges.length);
  check(diagram.id + ':no_invented_relationships', !/<<\s*(include|extend)\s*>>|<\|--|--\|>|\.\.>|<\.\.|\[hidden\]/i.test(text) && parsedEdges.length === lines.filter(line => / -- | -\[#/.test(line)).length, 'No semantic or hidden layout edges');
  check(diagram.id + ':primary_exact_catalog', diagram.associations.filter(edge => edge.kind === 'primary').every(edge => byId.get(edge.ucId).primaryActorIds.includes(edge.actorId) && byId.get(edge.ucId).matrix[edge.actorId].startsWith('P')), diagram.kind);
  check(diagram.id + ':limited_approved_only', diagram.associations.filter(edge => edge.kind === 'limited').every(edge => byId.get(edge.ucId).matrix[edge.actorId].startsWith('V') && manifest.variants.some(variant => variant.ucId === edge.ucId && variant.actorId === edge.actorId && variant.label === edge.label)), 'No V promoted to P');
  check(diagram.id + ':supporting_exact_catalog', diagram.associations.filter(edge => edge.kind === 'supporting').every(edge => byId.get(edge.ucId).supportingActorIds.includes(edge.actorId) && edge.label === 'nếu cấu hình/bật'), 'Provider links conditional');
  check(diagram.id + ':no_blocked_staff', diagram.associations.every(edge => edge.actorId !== 'A03' || !byId.get(edge.ucId).matrix.A03.startsWith('B')), 'Interceptor restrictions preserved');
  check(diagram.id + ':every_uc_has_primary', diagram.ucIds.every(id => diagram.associations.some(edge => edge.ucId === id && (edge.kind === 'primary' || diagram.kind === 'actor' && edge.kind === 'limited'))), diagram.ucIds.length);
  check(diagram.id + ':all_primary_edges_present', diagram.ucIds.every(id => byId.get(id).primaryActorIds.filter(actorId => diagram.kind !== 'actor' || actorId === diagram.actorId).every(actorId => diagram.associations.some(edge => edge.ucId === id && edge.actorId === actorId && edge.kind === 'primary'))), diagram.ucIds.length);
  check(diagram.id + ':status_labels_match', parsedUcs.every(match => { const source = byId.get(match[1].split('\\n')[0]); const expected = source.status === 'Một phần' ? ' <<Một phần>>' : source.status.includes('DEMO') ? ' <<DEMO>>' : source.status.includes('MÔ PHỎNG') ? ' <<MÔ PHỎNG>>' : ''; return match[3] === expected; }), 'Static vs partial/demo/mock');
  check(diagram.id + ':evidence_files_lines_exist', diagram.associations.every(edge => edge.evidence.length > 0 && edge.evidence.every(entry => fs.existsSync(path.join(root, entry.file)) && Number.isInteger(entry.line) && entry.line > 0 && entry.line <= fs.readFileSync(path.join(root, entry.file), 'utf8').split('\n').length)), 'Evidence line bounds only, not an automatic semantic proof');
}
const renderPath = path.join(directory, 'Render_Result.json');
if (fs.existsSync(renderPath)) {
  const render = JSON.parse(fs.readFileSync(renderPath, 'utf8'));
  check('render_all_real_plantuml', render.status === 'PASSED' && render.diagrams.length === manifest.diagrams.length && render.diagrams.every(item => item.syntaxExitCode === 0 && item.svgExitCode === 0 && item.pngExitCode === 0), render.status);
  check('render_hashes_match_current_sources_outputs', render.diagrams.every(item => ['source', 'svg', 'png'].every(kind => hash(path.join(directory, item[kind].file)) === item[kind].sha256)), 'Rerender required after any puml edit');
  check('svg_png_dimensions_positive', render.diagrams.every(item => item.svg.width > 0 && item.svg.height > 0 && Math.abs(item.png.width - item.svg.width) <= 1 && Math.abs(item.png.height - item.svg.height) <= 1), render.diagrams.length);
  check('all_visual_inspections_recorded', render.diagrams.every(item => item.visualInspection === 'Đã xem contact sheet; kiểm tra trang phức tạp ở kích thước đầy đủ.'), render.diagrams.length);
  for (const diagram of manifest.diagrams) {
    const svg = fs.readFileSync(path.join(directory, 'rendered', diagram.id + '.svg'), 'utf8');
    const entities = [...svg.matchAll(/<g class="entity" data-qualified-name="([^"]+)" id="([^"]+)"[^>]*>([\s\S]*?)<\/g>/g)];
    const renderedIds = entities.map(match => match[1].replace('SYSTEM.', ''));
    check(diagram.id + ':rendered_entities_exact', renderedIds.length === diagram.ucIds.length + diagram.actorIds.length && diagram.ucIds.every(id => renderedIds.includes(alias(id))) && diagram.actorIds.every(id => renderedIds.includes(id)), renderedIds.length);
    const cluster = svg.match(/<g class="cluster" data-qualified-name="SYSTEM"[^>]*><rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"/);
    const box = cluster && cluster.slice(1).map(Number);
    const ucShapes = entities.filter(match => match[1].startsWith('SYSTEM.')).map(match => { const shape = match[3].match(/<ellipse cx="([\d.]+)" cy="([\d.]+)" rx="([\d.]+)" ry="([\d.]+)"/); return shape && { alias: match[1].replace('SYSTEM.', ''), entity: match[2], values: shape.slice(1).map(Number) }; });
    check(diagram.id + ':rendered_ellipses_inside_boundary', box && ucShapes.every(shape => { if (!shape) return false; const [cx, cy, rx, ry] = shape.values; return cx - rx >= box[0] - 1 && cy - ry >= box[1] - 1 && cx + rx <= box[0] + box[2] + 1 && cy + ry <= box[1] + box[3] + 1; }), box);
    check(diagram.id + ':rendered_ellipses_no_overlap', ucShapes.every((first, index) => ucShapes.slice(index + 1).every(second => Math.abs(first.values[0] - second.values[0]) >= first.values[2] + second.values[2] || Math.abs(first.values[1] - second.values[1]) >= first.values[3] + second.values[3])), ucShapes.length);
    const actorOutside = entities.filter(match => !match[1].startsWith('SYSTEM.')).every(match => { const shape = match[3].match(/<ellipse cx="([\d.]+)" cy="([\d.]+)" rx="([\d.]+)" ry="([\d.]+)"/); if (!shape) return false; const [cx, cy, rx, ry] = shape.slice(1).map(Number); return cx + rx < box[0] || cx - rx > box[0] + box[2] || cy + ry < box[1] || cy - ry > box[1] + box[3]; });
    check(diagram.id + ':rendered_actors_outside_boundary', actorOutside, diagram.actorIds);
    const renderedEdges = [...svg.matchAll(/<g class="link" data-entity-1="([^"]+)" data-entity-2="([^"]+)"[^>]*data-link-type="association"[^>]*><path d="([^"]+)"/g)];
    const entityNames = new Map(entities.map(match => [match[2], match[1].replace('SYSTEM.', '')]));
    check(diagram.id + ':rendered_associations_exact', renderedEdges.length === diagram.associations.length && diagram.associations.every(edge => renderedEdges.filter(match => edge.kind === 'supporting' ? entityNames.get(match[1]) === alias(edge.ucId) && entityNames.get(match[2]) === edge.actorId : ((entityNames.get(match[1]) === edge.actorId && entityNames.get(match[2]) === alias(edge.ucId)) || (entityNames.get(match[2]) === edge.actorId && entityNames.get(match[1]) === alias(edge.ucId)))).length === 1), renderedEdges.length);
    const gaps = [];
    for (const edge of renderedEdges) {
      const coordinates = edge[3].match(/-?\d+(?:\.\d+)?/g).map(Number);
      for (const [entity, endpoint] of [[edge[1], coordinates.slice(0, 2)], [edge[2], coordinates.slice(-2)]]) {
        const shape = ucShapes.find(shape => shape.entity === entity);
        if (!shape) continue;
        const [cx, cy, rx, ry] = shape.values;
        const radialDistance = Math.sqrt(((endpoint[0] - cx) / rx) ** 2 + ((endpoint[1] - cy) / ry) ** 2);
        if (Math.abs(radialDistance - 1) > 0.12) gaps.push({ uc: shape.alias, radialDistance });
      }
    }
    check(diagram.id + ':rendered_edges_touch_ellipses', gaps.length === 0, gaps);
  }

}
const report = { status: failures.length ? 'FAILED' : 'PASSED', executedAt: new Date().toISOString(), checks: checks.length, failures, diagrams: manifest.diagrams.length, modulePages: details.length, actorPages: staff.length, useCases: new Set(detailedIds).size, groups: catalog.groups.length, changedSources, coverageMissing: catalog.useCases.filter(item => !detailedIds.includes(item.id)).map(item => item.id), detailedDuplicates: [...new Set(detailedIds.filter((id, index) => detailedIds.indexOf(id) !== index))], results: checks };
fs.writeFileSync(path.join(directory, 'Validation_Result.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ ...report, results: undefined }, null, 2));
if (failures.length) process.exitCode = 1;


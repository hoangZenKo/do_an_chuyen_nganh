const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');
const directory = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'data/diagram-manifest.json'), 'utf8'));
const java = process.env.JAVA_BIN || 'java';
const jar = process.env.PLANTUML_JAR;
if (!jar || !fs.existsSync(jar)) throw new Error('Set PLANTUML_JAR to a locally available PlantUML 1.2026.9 JAR.');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const run = args => {
  const result = childProcess.spawnSync(java, ['-Djava.awt.headless=true', '-DPLANTUML_LIMIT_SIZE=16000', '-jar', jar, ...args], { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
  return { exitCode: result.status, stdout: result.stdout || '', stderr: result.stderr || '', error: result.error?.message || null };
};
const version = run(['-version']);
const javaVersion = childProcess.spawnSync(java, ['-version'], { encoding: 'utf8' });
const output = path.join(directory, 'rendered');
fs.mkdirSync(output, { recursive: true });
const report = { status: 'RUNNING', executedAt: new Date().toISOString(), java, javaVersion: javaVersion.stderr, jarSha256: hash(jar), plantumlVersionProbe: version, renderer: 'PlantUML 1.2026.9 / Graphviz dot', graphvizDot: process.env.GRAPHVIZ_DOT || 'dot', graphvizProbe: childProcess.spawnSync(process.env.GRAPHVIZ_DOT || 'dot', ['-V'], { encoding: 'utf8' }).stderr, networkRendering: false, note: 'Local Graphviz via @viz-js/viz WASM or native dot. Each syntax/SVG/PNG command must exit 0.', diagrams: [] };
for (const diagram of manifest.diagrams) {
  const file = path.join(directory, diagram.file);
  const syntax = run(['-charset', 'UTF-8', '-checkonly', file]);
  const svgResult = run(['-charset', 'UTF-8', '-tsvg', '-o', output, file]);
  const pngResult = run(['-charset', 'UTF-8', '-tpng', '-o', output, file]);
  const svgFile = path.join(output, diagram.id + '.svg');
  const pngFile = path.join(output, diagram.id + '.png');
  if (syntax.exitCode || svgResult.exitCode || pngResult.exitCode || !fs.existsSync(svgFile) || !fs.existsSync(pngFile)) throw new Error(JSON.stringify({ diagram: diagram.id, syntax, svgResult, pngResult }));
  const svg = fs.readFileSync(svgFile, 'utf8');
  if (/Syntax Error|An error has occurred|java.lang.|data-diagram-type="ERROR"/.test(svg)) throw new Error('Error image: ' + diagram.id);
  const width = Number(svg.match(/<svg[^>]*\bwidth="([\d.]+)(?:px)?"/)[1]);
  const height = Number(svg.match(/<svg[^>]*\bheight="([\d.]+)(?:px)?"/)[1]);
  const bytes = fs.readFileSync(pngFile);
  if (bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error('Invalid PNG: ' + diagram.id);
  const source = { file: diagram.file, sha256: hash(file) };
  const svgInfo = { file: 'rendered/' + diagram.id + '.svg', sha256: hash(svgFile), width, height };
  const pngInfo = { file: 'rendered/' + diagram.id + '.png', sha256: hash(pngFile), width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  report.diagrams.push({ id: diagram.id, syntaxExitCode: syntax.exitCode, svgExitCode: svgResult.exitCode, pngExitCode: pngResult.exitCode, syntax, svgResult, pngResult, source, svg: svgInfo, png: pngInfo, visualInspection: 'Chưa kiểm tra trực quan' });
  console.log(diagram.id + ' ' + width + 'x' + height);
}
report.status = 'PASSED';
fs.writeFileSync(path.join(directory, 'Render_Result.json'), JSON.stringify(report, null, 2) + '\n');
console.log('Rendered ' + report.diagrams.length + ' SVG + ' + report.diagrams.length + ' PNG; all syntax/render exit codes 0.');


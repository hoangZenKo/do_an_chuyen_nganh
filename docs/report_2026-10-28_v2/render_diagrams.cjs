const fs = require('fs');
const path = require('path');
const root = '/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { instance } = require(path.join(root, '@viz-js/viz'));
const sharp = require(path.join(root, 'sharp'));
(async () => {
  const dir = '/tmp/rental-report-v2-20261028/diagrams';
  const manifest = JSON.parse(fs.readFileSync('/tmp/rental-report-v2-20261028/diagram-manifest.json','utf8'));
  const entries = new Map(manifest.map(item=>[item.id,item]));
  const viz = await instance();
  for (const filename of fs.readdirSync(dir).filter(x=>x.endsWith('.dot'))) {
    const entry = entries.get(filename.replace('.dot',''));
    if (!entry || entry.kind === 'usecase' || entry.kind === 'sequence') continue;
    const svg=viz.renderString(fs.readFileSync(path.join(dir,filename),'utf8'), {format:'svg',engine:'dot'});
    fs.writeFileSync(path.join(dir,filename.replace('.dot','.svg')),svg);
  }
  for (const filename of fs.readdirSync(dir).filter(x=>x.endsWith('.svg'))) {
    if (!entries.has(filename.replace('.svg',''))) continue;
    await sharp(Buffer.from(fs.readFileSync(path.join(dir,filename),'utf8')), {density:220,limitInputPixels:false})
      .resize({width:2200,withoutEnlargement:false}).flatten({background:'white'})
      .png().toFile(path.join(dir,filename.replace('.svg','.png')));
  }
  console.log('Rendered all diagram PNGs.');
})().catch(error=>{console.error(error);process.exit(1)});

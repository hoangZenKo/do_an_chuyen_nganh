#!/usr/bin/env node
const fs = require('node:fs');
const modulePath = process.env.VIZJS_MODULE;
if (!modulePath) throw new Error('Set VIZJS_MODULE to an external @viz-js/viz 3.17.0 installation.');
const vizModule = require(modulePath);
const args = process.argv.slice(2);
if (args.includes('-V')) {
  process.stderr.write('dot - graphviz version ' + vizModule.graphvizVersion + ' (@viz-js/viz WASM)\n');
} else {
  const source = fs.readFileSync(0, 'utf8');
  const format = (args.find(arg => arg.startsWith('-T')) || '-Tsvg').slice(2);
  vizModule.instance().then(viz => {
    process.stdout.write(viz.renderString(source, { engine: 'dot', format }));
  }).catch(error => {
    process.stderr.write(String(error));
    process.exitCode = 1;
  });
}


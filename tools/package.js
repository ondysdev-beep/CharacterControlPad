// Builds the release ZIP of the addon from the committed state (HEAD):
//   dist/ForeverPad-<version>.zip  containing  ForeverPad/...
// Steps: version check (TOC == Core.lua), clean working tree, full test suite, git archive.
// Usage: npm run package
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const repo = path.join(__dirname, '..');
const addon = path.join(repo, 'ForeverPad');
const fail = (msg) => { console.error('PACKAGE FAILED: ' + msg); process.exit(1); };
const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8' });

const toc = fs.readFileSync(path.join(addon, 'ForeverPad.toc'), 'utf8');
const tocVersion = (toc.match(/^## Version:\s*(\S+)/m) || [])[1];
const coreVersion = (fs.readFileSync(path.join(addon, 'Core.lua'), 'utf8').match(/ns\.VERSION = "([^"]+)"/) || [])[1];
if (!tocVersion || tocVersion !== coreVersion) fail(`version mismatch: TOC ${tocVersion} vs Core.lua ${coreVersion}`);

// Every file listed in the TOC must exist.
for (const line of toc.split(/\r?\n/)) {
  const file = line.trim();
  if (file && !file.startsWith('#') && !fs.existsSync(path.join(addon, file))) fail(`TOC lists missing file ${file}`);
}

if (git('status', '--porcelain').trim() !== '') fail('working tree is not clean - commit first (the ZIP is built from HEAD)');

try {
  execFileSync(process.execPath, [path.join(repo, 'tests', 'run-all.js')], { stdio: 'ignore' });
} catch (e) {
  fail('tests failed - run npm test');
}

fs.mkdirSync(path.join(repo, 'dist'), { recursive: true });
const out = path.join('dist', `ForeverPad-${tocVersion}.zip`);
git('archive', '--format=zip', '--prefix=ForeverPad/', '-o', out, 'HEAD:ForeverPad');
const size = fs.statSync(path.join(repo, out)).size;
console.log(`Created ${out} (${Math.round(size / 1024)} kB) from ${git('rev-parse', '--short', 'HEAD').trim()}`);

// Runs the whole offline test suite for the CharacterControlPad addon:
//   1. Lua 5.1 syntax check of every addon file (luaparse)
//   2. list of global identifiers used (to spot typos in WoW API names)
//   3. every *_test.lua with mocked WoW API in a Lua VM (fengari)
// Usage (from the repository root):  npm install  &&  npm test
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'CharacterControlPad') + path.sep;
const luaFiles = fs.readdirSync(root).filter(f => f.endsWith('.lua')).map(f => root + f);
let failed = false;

function run(script, args) {
  try {
    const out = execFileSync(process.execPath, [path.join(__dirname, script), ...args], { encoding: 'utf8' });
    process.stdout.write(out);
  } catch (e) {
    failed = true;
    process.stdout.write((e.stdout || '') + (e.stderr || ''));
  }
}

console.log('== syntax');
run('check.js', luaFiles);
console.log('== globals');
run('globals.js', luaFiles);
console.log('== tests');
for (const t of fs.readdirSync(__dirname).filter(f => f.endsWith('_test.lua')).sort()) {
  run('run.js', [path.join(__dirname, t), root]);
}
if (failed) {
  console.log('\nSOME CHECKS FAILED');
  process.exit(1);
}
console.log('\nALL CHECKS PASSED');

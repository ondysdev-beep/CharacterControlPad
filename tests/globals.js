const fs = require('fs'); const luaparse = require('luaparse');
const g = new Set();
function walk(n) {
  if (!n || typeof n !== 'object') return;
  if (Array.isArray(n)) { n.forEach(walk); return; }
  if (n.type === 'Identifier' && n.isLocal === false) g.add(n.name);
  for (const k of Object.keys(n)) if (k !== 'loc' && k !== 'range') walk(n[k]);
}
for (const f of process.argv.slice(2)) walk(luaparse.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.1', scope: true }));
console.log([...g].sort().join(' '));

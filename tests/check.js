const fs = require('fs'); const luaparse = require('luaparse');
let bad = 0;
for (const f of process.argv.slice(2)) {
  try { luaparse.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.1' }); console.log('OK   ' + f); }
  catch (e) { bad++; console.log('FAIL ' + f + ': ' + e.message); }
}
process.exit(bad ? 1 : 0);

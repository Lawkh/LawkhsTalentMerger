// Fengari's CLI can print Lua failures while returning exit code 0.
// Make runtime errors fail the npm check instead of accepting partial output.
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const runner = require.resolve('fengari-node-cli/src/lua-cli.js');
const files = process.argv.slice(2);
for (const file of files.length ? files : ['tests/localization_spec.lua', 'tests/core_spec.lua', 'tests/ui_spec.lua']) {
  const result = spawnSync(process.execPath, [runner, file], { cwd: root, encoding: 'utf8' });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error || result.status !== 0 || (result.stderr || '').trim()) {
    if (result.error) console.error(result.error.message);
    process.exit(1);
  }
}

import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

test('iOS build inputs and archive validation reject unsafe or incomplete packages', () => {
  const python = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
  const result = spawnSync(python, ['-m', 'unittest', 'discover', '-s', 'mobile/tests', '-v'], {
    cwd: fileURLToPath(new URL('..', import.meta.url)), encoding: 'utf8', windowsHide: true,
  });
  assert.equal(result.error, undefined, 'Python 3 is required; set PYTHON to its executable path if needed');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /Ran 11 tests/);
});

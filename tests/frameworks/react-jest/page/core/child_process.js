'use strict';

// Node's child_process in the browser page: a page starts no processes.

function unavailable(name) {
  return () => {
    throw Object.assign(new Error(`child_process.${name} is not available in the browser page`), {code: 'ENOSYS'});
  };
}

module.exports = Object.fromEntries(['spawn', 'spawnSync', 'exec', 'execSync', 'execFile', 'execFileSync', 'fork'].map(n => [n, unavailable(n)]));

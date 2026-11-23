'use strict';

// Node's os in the browser page: constant answers for the host Jest's worker would report on.

const page = __reactJestPage;

module.exports = {
  EOL: '\n',
  devNull: '/dev/null',
  platform: () => page.session.platform,
  arch: () => page.session.arch,
  type: () => (page.session.platform === 'darwin' ? 'Darwin' : 'Linux'),
  release: () => '0.0.0',
  version: () => '',
  machine: () => page.session.arch,
  hostname: () => 'localhost',
  homedir: () => '/nonexistent',
  tmpdir: () => '/tmp',
  endianness: () => 'LE',
  cpus: () => [],
  availableParallelism: () => 1,
  totalmem: () => 0,
  freemem: () => 0,
  loadavg: () => [0, 0, 0],
  uptime: () => 0,
  networkInterfaces: () => ({}),
  userInfo: () => ({uid: 501, gid: 20, username: 'jest', homedir: '/nonexistent', shell: null}),
  constants: {signals: {}, errno: {}, priority: {}},
};

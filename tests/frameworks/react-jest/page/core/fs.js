'use strict';

// Node's fs in the browser page: a read-only view of the React checkout and of this harness, answered
// by the server (server.mjs fsCall). What a Jest worker reads from disk - a test file's source, the
// host-config forks React's setup looks for, .snap files, a frame's source for a code frame - reads
// the same bytes; writes fail with EROFS (Jest in CI mode writes nothing). The checkout does not
// change during a run, so answers are kept.

const {call, native} = __reactJestPage;
const {Buffer} = require('buffer');

const constants = {
  F_OK: 0, R_OK: 4, W_OK: 2, X_OK: 1,
  O_RDONLY: 0, O_WRONLY: 1, O_RDWR: 2, O_CREAT: 0x200, O_EXCL: 0x800, O_TRUNC: 0x400, O_APPEND: 0x8,
  S_IFMT: 0o170000, S_IFREG: 0o100000, S_IFDIR: 0o040000, S_IFCHR: 0o020000, S_IFBLK: 0o060000,
  S_IFIFO: 0o010000, S_IFLNK: 0o120000, S_IFSOCK: 0o140000,
  COPYFILE_EXCL: 1, COPYFILE_FICLONE: 2, COPYFILE_FICLONE_FORCE: 4,
  UV_FS_COPYFILE_EXCL: 1,
};

function toPath(p) {
  if (typeof p === 'string') return p;
  if (p && typeof p === 'object' && p.protocol === 'file:') return decodeURIComponent(p.pathname);
  if (Buffer.isBuffer(p)) return p.toString('utf8');
  throw Object.assign(new TypeError(`The "path" argument must be of type string. Received ${typeof p}`), {code: 'ERR_INVALID_ARG_TYPE'});
}

function fsError(e) {
  const error = new Error(e.message);
  for (const k of ['code', 'errno', 'syscall', 'path']) if (e[k] !== undefined) error[k] = e[k];
  return error;
}

const answers = new Map();
function ask(op, path, extra) {
  const key = op + '\0' + path + '\0' + (extra ? JSON.stringify(extra) : '');
  let a = answers.get(key);
  if (!a) {
    try {
      a = {value: call('fs', {op, path, ...extra}).value};
    } catch (e) {
      a = {error: e};
    }
    answers.set(key, a);
  }
  if (a.error) throw fsError(a.error);
  return a.value;
}

class Stats {
  constructor(s) {
    Object.assign(this, s);
    for (const k of ['atime', 'mtime', 'ctime', 'birthtime']) this[k] = new Date(s[k + 'Ms']);
    delete this.file;
    delete this.directory;
    delete this.symlink;
    Object.defineProperty(this, '_kind', {value: s.file ? 'file' : s.directory ? 'directory' : s.symlink ? 'symlink' : 'other'});
  }
  isFile() { return this._kind === 'file'; }
  isDirectory() { return this._kind === 'directory'; }
  isSymbolicLink() { return this._kind === 'symlink'; }
  isBlockDevice() { return false; }
  isCharacterDevice() { return false; }
  isFIFO() { return false; }
  isSocket() { return false; }
}

class Dirent {
  constructor(d, parentPath) {
    this.name = d.name;
    this.parentPath = parentPath;
    this.path = parentPath;
    Object.defineProperty(this, '_kind', {value: d.file ? 'file' : d.directory ? 'directory' : d.symlink ? 'symlink' : 'other'});
  }
  isFile() { return this._kind === 'file'; }
  isDirectory() { return this._kind === 'directory'; }
  isSymbolicLink() { return this._kind === 'symlink'; }
  isBlockDevice() { return false; }
  isCharacterDevice() { return false; }
  isFIFO() { return false; }
  isSocket() { return false; }
}

function encodingOf(options) {
  if (typeof options === 'string') return options;
  return options && options.encoding ? options.encoding : null;
}

function statSync(p, options) {
  try {
    return new Stats(ask('stat', toPath(p)));
  } catch (e) {
    if (options && options.throwIfNoEntry === false && e.code === 'ENOENT') return undefined;
    throw e;
  }
}
function lstatSync(p, options) {
  try {
    return new Stats(ask('lstat', toPath(p)));
  } catch (e) {
    if (options && options.throwIfNoEntry === false && e.code === 'ENOENT') return undefined;
    throw e;
  }
}
function existsSync(p) {
  try {
    statSync(p);
    return true;
  } catch {
    return false;
  }
}
function readFileSync(p, options) {
  if (typeof p === 'number') throw Object.assign(new Error('EBADF: reading a file descriptor is not supported in the browser page'), {code: 'EBADF'});
  const encoding = encodingOf(options);
  if (encoding === 'utf8' || encoding === 'utf-8') return ask('read', toPath(p), {encoding: 'utf8'});
  const bytes = Buffer.from(ask('read', toPath(p)), 'base64');
  return encoding ? bytes.toString(encoding) : bytes;
}
function readdirSync(p, options) {
  const path = toPath(p);
  const entries = ask('readdir', path);
  if (options && typeof options === 'object' && options.withFileTypes) return entries.map(d => new Dirent(d, path));
  return entries.map(d => d.name);
}
function realpathSync(p) {
  return ask('realpath', toPath(p));
}
realpathSync.native = realpathSync;
function readlinkSync(p) {
  return ask('readlink', toPath(p));
}
function accessSync(p, mode) {
  statSync(p);
  if (mode & constants.W_OK) throw Object.assign(new Error(`EROFS: read-only file system, access '${toPath(p)}'`), {code: 'EROFS'});
}

function readOnly(name) {
  return function () {
    const p = arguments[0];
    throw Object.assign(new Error(`EROFS: the browser page's file view is read-only, ${name} '${typeof p === 'string' ? p : ''}'`), {code: 'EROFS', syscall: name});
  };
}
const writes = ['writeFile', 'appendFile', 'mkdir', 'mkdtemp', 'rm', 'rmdir', 'unlink', 'rename', 'copyFile', 'cp', 'symlink', 'link',
  'chmod', 'lchmod', 'chown', 'lchown', 'utimes', 'lutimes', 'futimes', 'truncate', 'ftruncate', 'open', 'close', 'write', 'read',
  'fsync', 'fdatasync', 'fstat', 'fchmod', 'fchown', 'opendir', 'watch', 'watchFile', 'unwatchFile', 'createReadStream', 'createWriteStream'];

const fs = {
  constants,
  Stats,
  Dirent,
  statSync,
  lstatSync,
  existsSync,
  readFileSync,
  readdirSync,
  realpathSync,
  readlinkSync,
  accessSync,
};
for (const name of writes) {
  const sync = readOnly(name);
  fs[name + 'Sync'] = sync;
  if (!['watch', 'watchFile', 'unwatchFile', 'createReadStream', 'createWriteStream'].includes(name)) {
    fs[name] = (...args) => {
      const cb = typeof args[args.length - 1] === 'function' ? args.pop() : null;
      let error;
      try {
        sync(...args);
      } catch (e) {
        error = e;
      }
      if (cb) native.setTimeout(() => cb(error), 0);
    };
  } else {
    fs[name] = sync;
  }
}
delete fs.watchSync;
delete fs.watchFileSync;
delete fs.unwatchFileSync;
delete fs.createReadStreamSync;
delete fs.createWriteStreamSync;

// Node's callback forms: the answer in a later task, as libuv gives it.
for (const name of ['stat', 'lstat', 'readFile', 'readdir', 'realpath', 'readlink', 'access']) {
  const sync = fs[name + 'Sync'];
  fs[name] = (...args) => {
    const cb = args.pop();
    let value;
    let error = null;
    try {
      value = sync(...args);
    } catch (e) {
      error = e;
    }
    native.setTimeout(() => cb(error, value), 0);
  };
}
fs.realpath.native = fs.realpath;
fs.exists = (p, cb) => native.setTimeout(() => cb(existsSync(p)), 0);

const promises = {constants};
for (const name of ['stat', 'lstat', 'readFile', 'readdir', 'realpath', 'readlink', 'access']) {
  const sync = fs[name + 'Sync'];
  promises[name] = async (...args) => sync(...args);
}
for (const name of writes) {
  if (fs[name + 'Sync']) promises[name] = async (...args) => fs[name + 'Sync'](...args);
}
fs.promises = promises;

module.exports = fs;

'use strict';

// Node's module in the browser page: what Jest reads of it - the list of core modules, isBuiltin,
// createRequire (the page's own loader) and the Module class jest-runtime extends.

const page = __reactJestPage;

class Module {
  constructor(id = '', parent) {
    this.id = id;
    this.path = '.';
    this.exports = {};
    this.parent = parent;
    this.filename = null;
    this.loaded = false;
    this.children = [];
    this.paths = [];
  }
}
Module.builtinModules = page.session.builtinModules;
Module.isBuiltin = name => {
  const n = String(name);
  return page.session.builtinModules.includes(n.startsWith('node:') ? n.slice(5) : n);
};
Module.createRequire = filename => page.makeRequire(typeof filename === 'string' ? filename : decodeURIComponent(filename.pathname));
Module.wrap = script => '(function (exports, require, module, __filename, __dirname) { ' + script + '\n});';
Module.wrapper = ['(function (exports, require, module, __filename, __dirname) { ', '\n});'];
Module._extensions = {'.js': null, '.json': null, '.node': null};
Module._cache = {};
Module.globalPaths = [];
Module.syncBuiltinESMExports = () => {};
Module.findSourceMap = () => undefined;
Module.register = () => {};
Module.Module = Module;

module.exports = Module;

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
// Node's own compile of a module's source (React's react-server-dom-webpack node-register wraps it):
// the source in Node's wrapper, run with Node's require for its file - the page's loader, which is
// what Node's own loader is outside Jest's runtime.
Module.prototype._compile = function _compile(content, filename) {
  page.runNodeModule(this, content, filename);
};
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

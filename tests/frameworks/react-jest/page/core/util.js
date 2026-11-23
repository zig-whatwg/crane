'use strict';

// Node's util in the browser page: the npm `util` package (Node's own util, published for
// browsers), with what it lacks from Node 20 that Jest and React's tests use - Node's own inspect and
// format (node-inspect-extracted: Node's lib/internal/util/inspect.js with only its requires
// changed; React's consoleMock formats every console call with util.format, and the tests compare
// the text, so the old inspect of the npm package would not do), the browser's TextEncoder and
// TextDecoder (Node's util exports the same classes as its globals) and util.types.

const {native} = __reactJestPage;
const util = require('util/');
const nodeInspect = require('node-inspect-extracted');
const types = require('./util__types.js');

module.exports = Object.assign({}, util, {
  inspect: nodeInspect.inspect,
  format: nodeInspect.format,
  formatWithOptions: nodeInspect.formatWithOptions,
  stripVTControlCharacters: nodeInspect.stripVTControlCharacters,
  TextEncoder: native.TextEncoder,
  TextDecoder: native.TextDecoder,
  types,
  isDeepStrictEqual(a, b) {
    return require('assert/').isDeepStrictEqual ? require('assert/').isDeepStrictEqual(a, b) : JSON.stringify(a) === JSON.stringify(b);
  },
  toUSVString: s => String(s).toWellFormed(),
  getSystemErrorName: code => `Unknown system error ${code}`,
  styleText: (_format, text) => text,
});

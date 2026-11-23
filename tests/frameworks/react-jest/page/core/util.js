'use strict';

// Node's util in the browser page: the npm `util` package (Node's own util, published for
// browsers), with what it lacks from Node 20 that Jest and React's tests use - the browser's
// TextEncoder and TextDecoder (Node's util exports the same classes as its globals) and util.types.

const {native} = __reactJestPage;
const util = require('util/');
const types = require('./util__types.js');

const ansi = /[\u001B\u009B][[\]()#;?]*(?:(?:(?:(?:;[-a-zA-Z\d\/#&.:=?%@~_]+)*|[a-zA-Z\d]+(?:;[-a-zA-Z\d\/#&.:=?%@~_]*)*)?\u0007)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PR-TZcf-ntqry=><~]))/g;

module.exports = Object.assign({}, util, {
  TextEncoder: native.TextEncoder,
  TextDecoder: native.TextDecoder,
  types,
  stripVTControlCharacters: s => String(s).replace(ansi, ''),
  isDeepStrictEqual(a, b) {
    return require('assert/').isDeepStrictEqual ? require('assert/').isDeepStrictEqual(a, b) : JSON.stringify(a) === JSON.stringify(b);
  },
  toUSVString: s => String(s).toWellFormed(),
  getSystemErrorName: code => `Unknown system error ${code}`,
  styleText: (_format, text) => text,
});

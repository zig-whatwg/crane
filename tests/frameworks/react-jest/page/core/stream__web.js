'use strict';

// Node's stream/web in the browser page: the browser's own web streams, captured at page start (Node
// exports its classes, which are the same as its globals, whatever a test puts on the global).

module.exports = Object.assign({}, __reactJestPage.native.webStreams);

'use strict';

// Node's stream/promises in the browser page: readable-stream's promise forms.

module.exports = require('readable-stream').promises || require('readable-stream/lib/stream/promises');

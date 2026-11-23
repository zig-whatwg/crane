'use strict';

// Node's tty in the browser page: no terminal (Jest's worker in CI writes to a pipe).

class ReadStream {}
class WriteStream {}

module.exports = {isatty: () => false, ReadStream, WriteStream};

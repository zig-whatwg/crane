'use strict';

// Node's stream in the browser page: readable-stream (Node's streams, published for browsers), with
// the web-stream adapters it leaves out - Readable.toWeb and Readable.fromWeb, which React's Flight
// tests use to hand a Node stream to the browser client. They follow Node 20's
// lib/internal/webstreams/adapters.js (newReadableStreamFromStreamReadable,
// newStreamReadableFromReadableStream; Node is MIT-licensed), over the browser's own ReadableStream.

const rs = require('readable-stream');
const {Buffer} = require('buffer');

const {Readable, finished} = rs;

function newReadableStreamFromStreamReadable(streamReadable, options = {}) {
  if (typeof streamReadable?._readableState !== 'object') {
    throw Object.assign(new TypeError('The "streamReadable" argument must be an instance of stream.Readable.'), {code: 'ERR_INVALID_ARG_TYPE'});
  }
  if (streamReadable.destroyed || streamReadable.readable === false) {
    const readable = new ReadableStream();
    readable.cancel();
    return readable;
  }
  const objectMode = streamReadable.readableObjectMode;
  const highWaterMark = streamReadable.readableHighWaterMark;
  const strategy =
    options.strategy ||
    (objectMode ? new CountQueuingStrategy({highWaterMark}) : {highWaterMark});
  let controller;
  function onData(chunk) {
    // Copy the Buffer to detach it from the pool.
    if (Buffer.isBuffer(chunk) && !objectMode) chunk = new Uint8Array(chunk);
    controller.enqueue(chunk);
    if (controller.desiredSize <= 0) streamReadable.pause();
  }
  function onFinished(error) {
    cleanup();
    // This is to work around a bug in Node's readable stream: errors after close are swallowed.
    streamReadable.on('error', () => {});
    if (error) {
      if (error.code === 'ERR_STREAM_PREMATURE_CLOSE') {
        const abort = new DOMException('The operation was aborted', 'AbortError');
        abort.cause = error;
        return controller.error(abort);
      }
      return controller.error(error);
    }
    controller.close();
  }
  streamReadable.pause();
  const cleanup = finished(streamReadable, onFinished);
  streamReadable.on('data', onData);
  return new ReadableStream(
    {
      start(c) {
        controller = c;
      },
      pull() {
        streamReadable.resume();
      },
      cancel(reason) {
        streamReadable.destroy(reason);
      },
    },
    strategy
  );
}

function newStreamReadableFromReadableStream(readableStream, options = {}) {
  const {highWaterMark, encoding, objectMode = false, signal} = options;
  const reader = readableStream.getReader();
  let closed = false;
  const readable = new Readable({
    objectMode,
    highWaterMark,
    encoding,
    signal,
    read() {
      reader.read().then(
        chunk => {
          if (chunk.done) {
            readable.push(null);
          } else {
            readable.push(chunk.value);
          }
        },
        error => readable.destroy(error)
      );
    },
    destroy(error, callback) {
      function done() {
        try {
          callback(error);
        } catch (e) {
          queueMicrotask(() => {
            throw e;
          });
        }
      }
      if (!closed) {
        reader.cancel(error).then(done, done);
        return;
      }
      done();
    },
  });
  reader.closed.then(
    () => {
      closed = true;
    },
    error => {
      closed = true;
      readable.destroy(error);
    }
  );
  return readable;
}

Readable.toWeb = (streamReadable, options) => newReadableStreamFromStreamReadable(streamReadable, options);
Readable.fromWeb = (readableStream, options) => newStreamReadableFromReadableStream(readableStream, options);

module.exports = rs;

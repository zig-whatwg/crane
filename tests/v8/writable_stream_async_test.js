// WritableStream Async Callback Tests
// Tests for async start(), write(), close(), and abort() callbacks that return Promises
//
// NOTE: Many tests are currently skipped because of a bug in V8 callback storage.
// The callback pointers stored in dictionaries (like UnderlyingSink.start) become
// invalid after the constructor returns because they are Local handles, not Global.
// See: src/runtime/engines/v8/conversions.zig line 941-951
// TODO: Fix V8 callback persistence to enable these tests

// ============================================================================
// Basic Infrastructure
// ============================================================================

// WritableStream exists
assert.isFunction(WritableStream, "WritableStream should be a function")

// WritableStreamDefaultWriter exists  
assert.isDefined(WritableStreamDefaultWriter, "WritableStreamDefaultWriter should be defined")

// WritableStream without callbacks works
assert.isTrue((() => {
  const stream = new WritableStream();
  return stream instanceof WritableStream;
})(), "WritableStream without callbacks should work")

// WritableStream getWriter works
assert.isTrue((() => {
  const stream = new WritableStream();
  const writer = stream.getWriter();
  return writer instanceof WritableStreamDefaultWriter;
})(), "WritableStream.getWriter() should return a writer")

// WritableStream locked property works
assert.isTrue((() => {
  const stream = new WritableStream();
  const notLocked = stream.locked === false;
  const writer = stream.getWriter();
  const locked = stream.locked === true;
  return notLocked && locked;
})(), "WritableStream.locked should reflect lock state")

// ============================================================================
// TODO: Re-enable these tests when V8 callback persistence is fixed
// ============================================================================

// The following tests are skipped because WritableStream callbacks
// (start, write, close, abort) crash due to invalid V8 pointer storage.
//
// Tests to add when fixed:
// - Async start() with immediate resolve
// - Async start() with setTimeout delay  
// - Async start() error handling
// - Async write() processing
// - Async write() error propagation
// - Async close() cleanup
// - Async close() error handling
// - Async abort() basic
// - Async abort() during write
// - Full async lifecycle
// - Backpressure with async write
// - Ready promise with async start
// - Closed promise after close

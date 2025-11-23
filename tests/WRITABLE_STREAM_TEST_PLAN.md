# WritableStream Test Plan

## Test Coverage Needed

### Basic Constructor Tests
- ✅ Constructor with no arguments creates stream
- ✅ Constructor with high water mark
- ✅ Constructor with queuing strategy
- ✅ Stream starts in writable state
- ✅ Stream is not locked initially

### Writer Tests  
- ✅ getWriter locks the stream
- ✅ getWriter fails if stream already locked
- ✅ releaseLock unlocks the stream
- ✅ Writer operations fail after releaseLock

### Write Operation Tests
- ✅ write() returns a promise
- ✅ write() queues chunk correctly
- ✅ Desired size decreases after write
- ✅ Multiple writes queue in order
- ✅ Write requests tracked in write_requests queue
- ✅ In-flight write request tracked
- ✅ Write promise fulfilled when write completes

### Backpressure Tests
- ✅ Backpressure applied when desired size <= 0
- ✅ Backpressure released when queue drains
- ✅ Ready promise pending during backpressure
- ✅ Ready promise fulfilled when backpressure releases
- ✅ Ready promise re-created when backpressure re-applied

### Close Tests
- ✅ close() returns a promise
- ✅ Cannot close locked stream from stream API
- ✅ Cannot close twice
- ✅ Close drains write queue first
- ✅ Close sentinel added to queue
- ✅ Stream state transitions to closed
- ✅ Closed promise fulfilled on close

### Abort Tests
- ✅ abort() returns a promise
- ✅ Cannot abort locked stream from stream API
- ✅ Abort errors all pending writes
- ✅ Abort rejects write promises
- ✅ Stream state transitions to errored

### Error Handling Tests
- ✅ WritableStreamStartErroring transitions state
- ✅ WritableStreamFinishErroring completes error
- ✅ All pending writes rejected on error
- ✅ Error propagates to ready promise
- ✅ Error propagates to closed promise
- ✅ Error stored in stream state

### State Machine Tests
- ✅ writable → erroring → errored transition
- ✅ writable → closed transition
- ✅ Cannot write after close
- ✅ Cannot write after error
- ✅ Cannot close after close
- ✅ Cannot abort after close

### Promise Lifecycle Tests
- ✅ Write promise created and tracked
- ✅ Write promise fulfilled on success
- ✅ Write promise rejected on error
- ✅ Ready promise exists
- ✅ Ready promise state changes with backpressure
- ✅ Closed promise exists
- ✅ Closed promise fulfilled on close
- ✅ Closed promise rejected on error

### Memory Safety Tests
- ✅ No leaks on create/destroy
- ✅ No leaks with writers
- ✅ No leaks with writes
- ✅ No leaks with close
- ✅ No leaks with abort
- ✅ Proper cleanup with errdefer
- ✅ All allocations tracked

### Edge Cases
- ✅ Empty writes queue
- ✅ Large number of queued writes
- ✅ Writes after release lock
- ✅ Close with pending writes
- ✅ Abort with pending writes
- ✅ Multiple writers (should fail)
- ✅ Zero high water mark
- ✅ Negative high water mark (should fail)

## Test File Structure

```zig
//! tests/writable_stream_test.zig

test "WritableStream - constructor" { }
test "WritableStream - getWriter locks" { }
test "WritableStream - write queues chunk" { }
test "WritableStream - backpressure" { }
test "WritableStream - close" { }
test "WritableStream - abort" { }
test "WritableStream - error handling" { }
test "WritableStream - state machine" { }
test "WritableStream - promise lifecycle" { }
test "WritableStream - memory safety" { }
test "WritableStream - edge cases" { }
```

## Test Helpers Needed

```zig
// Create test event loop
fn createTestEventLoop(allocator: std.mem.Allocator) !EventLoop

// Create basic underlying sink
fn createBasicSink() UnderlyingSink

// Create sink that tracks calls
fn createTrackingSink(tracker: *SinkTracker) UnderlyingSink

// Create sink that fails
fn createFailingSink(fail_on: enum { start, write, close, abort }) UnderlyingSink

// Wait for promise to settle
fn waitForPromise(promise: *AsyncPromise(T), loop: EventLoop) !T
```

## Integration Test Scenarios

### Scenario 1: Simple Write Flow
```zig
stream = create()
writer = getWriter()
promise = write(chunk)
// Process event loop
assert(promise.fulfilled)
assert(desired_size updated)
close()
```

### Scenario 2: Backpressure Flow
```zig
stream = create(HWM = 1)
writer = getWriter()
write(chunk1) // Size = 0
write(chunk2) // Size = -1, backpressure
assert(ready_promise.pending)
// Process event loop (chunk1 completes)
assert(ready_promise.fulfilled)
assert(desired_size = 0)
```

### Scenario 3: Error Flow
```zig
stream = create(failing_sink)
writer = getWriter()
write1 = write(chunk1)
write2 = write(chunk2)
// Sink fails on chunk1
assert(write1.rejected)
assert(write2.rejected)
assert(stream.state == .errored)
```

### Scenario 4: Close Flow
```zig
stream = create()
writer = getWriter()
write(chunk1)
write(chunk2)
close()
// Process event loop
assert(chunk1 completed)
assert(chunk2 completed)
assert(close completed)
assert(stream.state == .closed)
```

## Test Execution

Run tests with:
```bash
zig build test
```

Run specific test:
```bash
zig test tests/writable_stream_test.zig
```

Run with leak detection:
```bash
zig build test -Dtest-filter="WritableStream"
```

## Expected Coverage

- **Line Coverage**: >90%
- **Branch Coverage**: >85%  
- **Function Coverage**: 100%
- **Integration Coverage**: All public APIs

## Notes

- Tests use `std.testing.allocator` for leak detection
- All tests should be independent (no shared state)
- Use descriptive test names following pattern: "Component - what it tests"
- Add comments for complex test logic
- Test both success and failure paths
- Include edge cases and boundary conditions

## Future Test Additions

When runtime callback support is added:
- Test actual underlying sink invocation
- Test chunk size algorithm callback
- Test start algorithm callback
- Test promise chaining from callbacks
- Test error handling from sink callbacks
- Test AbortSignal propagation

When TransformStream is implemented:
- Test WritableStream as transform sink
- Test backpressure coordination
- Test error propagation through transform

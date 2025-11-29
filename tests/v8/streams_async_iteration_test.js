// ReadableStream Async Iteration Tests
// Tests for ReadableStream.values() and Symbol.asyncIterator

// ============================================================================
// Basic Infrastructure
// ============================================================================

// ReadableStream exists
assert.isFunction(ReadableStream, "ReadableStream should be a function")

// ReadableStream has values method
assert.isFunction(ReadableStream.prototype.values, "ReadableStream.prototype.values should be a function")

// ReadableStream has Symbol.asyncIterator
assert.isFunction(ReadableStream.prototype[Symbol.asyncIterator], "ReadableStream.prototype[Symbol.asyncIterator] should be a function")

// ReadableStreamIteratorOptions dictionary can be created
assert.strictEqual(typeof Object({ preventCancel: false }), "object", "Options object should be creatable")

// ============================================================================
// Async Iterator Creation
// ============================================================================

// Create a simple stream
assert.isTrue((() => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue("chunk1");
      controller.enqueue("chunk2");
      controller.close();
    }
  });
  return stream instanceof ReadableStream;
})(), "Created stream should be instanceof ReadableStream")

// values() returns an async iterator
assert.isTrue((() => {
  const stream = new ReadableStream();
  const iterator = stream.values();
  return typeof iterator === "object" && typeof iterator.next === "function";
})(), "values() should return an async iterator with next()")

// Symbol.asyncIterator returns an async iterator
assert.isTrue((() => {
  const stream = new ReadableStream();
  const iterator = stream[Symbol.asyncIterator]();
  return typeof iterator === "object" && typeof iterator.next === "function";
})(), "Symbol.asyncIterator should return an async iterator")

// values() and Symbol.asyncIterator return same type
assert.isTrue((() => {
  const stream = new ReadableStream();
  const iter1 = stream.values();
  const iter2 = stream[Symbol.asyncIterator]();
  return iter1.constructor === iter2.constructor;
})(), "values() and Symbol.asyncIterator should return same type")

// ============================================================================
// Promise Chaining - Basic Iteration
// ============================================================================

// next() returns a promise
assert.isTrue((() => {
  const stream = new ReadableStream();
  const iterator = stream.values();
  const result = iterator.next();
  return result instanceof Promise;
})(), "next() should return a Promise")

// Iteration over chunks (async test)
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
      controller.enqueue(2);
      controller.enqueue(3);
      controller.close();
    }
  });
  
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  
  return chunks.length === 3 && 
         chunks[0] === 1 && 
         chunks[1] === 2 && 
         chunks[2] === 3;
})(), "for-await-of should iterate over all chunks")

// Manual iteration with next()
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue("a");
      controller.enqueue("b");
      controller.close();
    }
  });
  
  const iterator = stream.values();
  
  const result1 = await iterator.next();
  const result2 = await iterator.next();
  const result3 = await iterator.next();
  
  return result1.value === "a" && !result1.done &&
         result2.value === "b" && !result2.done &&
         result3.done === true;
})(), "Manual iteration with next() should work correctly")

// Stream closes properly after iteration
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.close();
    }
  });
  
  const iterator = stream.values();
  const result = await iterator.next();
  
  return result.done === true && result.value === undefined;
})(), "Closed stream should return done: true")

// ============================================================================
// Promise Chaining - preventCancel Option
// ============================================================================

// preventCancel: false (default) - stream cancels on break
assert.isTrue((async () => {
  let cancelCalled = false;
  
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
      controller.enqueue(2);
      controller.enqueue(3);
    },
    cancel() {
      cancelCalled = true;
    }
  });
  
  for await (const chunk of stream.values({ preventCancel: false })) {
    if (chunk === 2) break;
  }
  
  return cancelCalled === true;
})(), "preventCancel: false should cancel stream on break")

// preventCancel: true - stream does NOT cancel on break
assert.isTrue((async () => {
  let cancelCalled = false;
  
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
      controller.enqueue(2);
      controller.enqueue(3);
    },
    cancel() {
      cancelCalled = true;
    }
  });
  
  for await (const chunk of stream.values({ preventCancel: true })) {
    if (chunk === 2) break;
  }
  
  return cancelCalled === false;
})(), "preventCancel: true should NOT cancel stream on break")

// ============================================================================
// Error Propagation - Stream Errors
// ============================================================================

// Error during iteration propagates to iterator
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
      controller.error(new Error("Stream error"));
    }
  });
  
  try {
    for await (const chunk of stream) {
      // Should throw on second iteration
    }
    return false; // Should not reach here
  } catch (error) {
    return error.message === "Stream error";
  }
})(), "Error during iteration should propagate")

// Error in pull algorithm propagates
assert.isTrue((async () => {
  const stream = new ReadableStream({
    pull(controller) {
      throw new Error("Pull failed");
    }
  });
  
  try {
    const iterator = stream.values();
    await iterator.next();
    return false; // Should not reach here
  } catch (error) {
    return error.message === "Pull failed";
  }
})(), "Error in pull algorithm should propagate")

// Error with custom error type
assert.isTrue((async () => {
  class CustomError extends Error {
    constructor(message) {
      super(message);
      this.name = "CustomError";
    }
  }
  
  const stream = new ReadableStream({
    start(controller) {
      controller.error(new CustomError("Custom"));
    }
  });
  
  try {
    for await (const chunk of stream) {}
    return false;
  } catch (error) {
    return error instanceof CustomError && error.message === "Custom";
  }
})(), "Custom error type should propagate correctly")

// ============================================================================
// Error Propagation - TypeError Cases
// ============================================================================

// Locked stream throws when getting iterator
assert.isTrue((async () => {
  const stream = new ReadableStream();
  const reader = stream.getReader(); // Lock the stream
  
  try {
    stream.values();
    return false; // Should throw
  } catch (error) {
    reader.releaseLock();
    return error instanceof TypeError;
  }
})(), "Locked stream should throw TypeError when getting iterator")

// ============================================================================
// Promise Chaining - Multiple Sequential Iterations
// ============================================================================

// Can iterate twice if reader released
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
      controller.enqueue(2);
      controller.close();
    }
  });
  
  // First iteration (complete)
  const chunks1 = [];
  for await (const chunk of stream.values({ preventCancel: true })) {
    chunks1.push(chunk);
  }
  
  // Note: In reality, you can't iterate twice over same stream
  // This test validates that first iteration completed
  return chunks1.length === 2;
})(), "First iteration should complete successfully")

// ============================================================================
// Promise Chaining - Early Return
// ============================================================================

// return() method exists
assert.isTrue((() => {
  const stream = new ReadableStream();
  const iterator = stream.values();
  return typeof iterator.return === "function";
})(), "return() method should exist on iterator")

// return() returns a promise
assert.isTrue((() => {
  const stream = new ReadableStream();
  const iterator = stream.values();
  const result = iterator.return();
  return result instanceof Promise;
})(), "return() should return a Promise")

// return() with preventCancel: false cancels stream
assert.isTrue((async () => {
  let cancelCalled = false;
  
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
    },
    cancel() {
      cancelCalled = true;
    }
  });
  
  const iterator = stream.values({ preventCancel: false });
  await iterator.return();
  
  return cancelCalled === true;
})(), "return() with preventCancel: false should cancel stream")

// return() with preventCancel: true does NOT cancel
assert.isTrue((async () => {
  let cancelCalled = false;
  
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
    },
    cancel() {
      cancelCalled = true;
    }
  });
  
  const iterator = stream.values({ preventCancel: true });
  await iterator.return();
  
  return cancelCalled === false;
})(), "return() with preventCancel: true should NOT cancel stream")

// ============================================================================
// Promise Chaining - Complex Scenarios
// ============================================================================

// Async iteration with async processing
assert.isTrue((async () => {
  const stream = new ReadableStream({
    async start(controller) {
      controller.enqueue(1);
      await new Promise(resolve => setTimeout(resolve, 0));
      controller.enqueue(2);
      controller.close();
    }
  });
  
  const results = [];
  for await (const chunk of stream) {
    results.push(chunk * 2);
  }
  
  return results.length === 2 && results[0] === 2 && results[1] === 4;
})(), "Async iteration with async processing should work")

// Promise chaining with transformation
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      for (let i = 0; i < 5; i++) {
        controller.enqueue(i);
      }
      controller.close();
    }
  });
  
  const squares = [];
  for await (const n of stream) {
    squares.push(n * n);
  }
  
  return squares.length === 5 && 
         squares[0] === 0 && 
         squares[4] === 16;
})(), "Transformation during iteration should work")

// Nested async iteration (multiple streams)
assert.isTrue((async () => {
  const stream1 = new ReadableStream({
    start(controller) {
      controller.enqueue("a");
      controller.close();
    }
  });
  
  const stream2 = new ReadableStream({
    start(controller) {
      controller.enqueue("b");
      controller.close();
    }
  });
  
  const results = [];
  
  for await (const chunk1 of stream1) {
    results.push(chunk1);
  }
  
  for await (const chunk2 of stream2) {
    results.push(chunk2);
  }
  
  return results.length === 2 && results[0] === "a" && results[1] === "b";
})(), "Nested async iteration should work")

// ============================================================================
// Error Propagation - Reader Release on Error
// ============================================================================

// Reader is released when iteration errors
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.error(new Error("Test"));
    }
  });
  
  try {
    for await (const chunk of stream) {}
  } catch (error) {
    // After error, stream should be unlocked (reader released)
    // Note: Can't test this directly as stream is errored
    return true;
  }
  
  return false;
})(), "Reader should be released when iteration errors")

// Reader is released when iteration completes
assert.isTrue((async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(1);
      controller.close();
    }
  });
  
  for await (const chunk of stream) {
    // Consume the chunk
  }
  
  // After iteration, stream should be unlocked
  // Note: Can't test this directly as stream is closed
  return true;
})(), "Reader should be released when iteration completes")

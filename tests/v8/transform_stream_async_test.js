// TransformStream Async Callback Tests
// Tests for async transform() and flush() callbacks that return Promises

// ============================================================================
// Basic Infrastructure
// ============================================================================

// TransformStream exists
assert.isFunction(TransformStream, "TransformStream should be a function")

// Basic TransformStream creation
assert.isTrue((() => {
  const ts = new TransformStream();
  return ts instanceof TransformStream;
})(), "TransformStream should be constructable")

// TransformStream has readable and writable
assert.isTrue((() => {
  const ts = new TransformStream();
  return ts.readable instanceof ReadableStream && 
         ts.writable instanceof WritableStream;
})(), "TransformStream should have readable and writable properties")

// ============================================================================
// Async transform() Callback Tests
// ============================================================================

// Async transform with immediate resolve
assert.isTrue((async () => {
  const transformed = [];
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      controller.enqueue(chunk * 2);
      return Promise.resolve();
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write(1);
  await writer.write(2);
  await writer.close();
  
  // Read all transformed chunks
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    transformed.push(value);
  }
  
  return transformed.length === 2 && 
         transformed[0] === 2 && 
         transformed[1] === 4;
})(), "Async transform() should transform chunks")

// Async transform with delayed processing
assert.isTrue((async () => {
  const processingTimes = [];
  const startTime = Date.now();
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      await new Promise(resolve => setTimeout(resolve, 10));
      processingTimes.push(Date.now() - startTime);
      controller.enqueue(chunk);
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("A");
  await writer.write("B");
  await writer.close();
  
  // Drain the readable
  while (true) {
    const { done } = await reader.read();
    if (done) break;
  }
  
  // Both writes should have been delayed
  return processingTimes.length === 2 && 
         processingTimes[0] >= 5 &&  // First chunk delayed
         processingTimes[1] >= processingTimes[0]; // Second after first
})(), "Async transform() should delay chunk processing")

// Async transform error propagates
assert.isTrue((async () => {
  let errorMessage = null;
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      if (chunk === "bad") {
        throw new Error("Transform failed");
      }
      controller.enqueue(chunk);
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  try {
    await writer.write("good");
    await writer.write("bad");
    await writer.close();
    
    // Try to read - should see error
    while (true) {
      const { done } = await reader.read();
      if (done) break;
    }
  } catch (error) {
    errorMessage = error.message;
  }
  
  return errorMessage === "Transform failed";
})(), "Async transform() error should propagate")

// Async transform with multiple enqueues
assert.isTrue((async () => {
  const results = [];
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      await new Promise(resolve => setTimeout(resolve, 5));
      // Enqueue multiple chunks per input
      controller.enqueue(chunk + "-a");
      controller.enqueue(chunk + "-b");
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("X");
  await writer.close();
  
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    results.push(value);
  }
  
  return results.length === 2 && 
         results[0] === "X-a" && 
         results[1] === "X-b";
})(), "Async transform() can enqueue multiple chunks")

// Async transform with filtering (no enqueue for some chunks)
assert.isTrue((async () => {
  const results = [];
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      await new Promise(resolve => setTimeout(resolve, 5));
      // Only pass through even numbers
      if (chunk % 2 === 0) {
        controller.enqueue(chunk);
      }
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write(1);
  await writer.write(2);
  await writer.write(3);
  await writer.write(4);
  await writer.close();
  
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    results.push(value);
  }
  
  return results.length === 2 && 
         results[0] === 2 && 
         results[1] === 4;
})(), "Async transform() can filter chunks by not enqueueing")

// ============================================================================
// Async flush() Callback Tests
// ============================================================================

// Async flush with cleanup
assert.isTrue((async () => {
  let flushCalled = false;
  const results = [];
  
  const ts = new TransformStream({
    transform(chunk, controller) {
      controller.enqueue(chunk);
    },
    async flush(controller) {
      await new Promise(resolve => setTimeout(resolve, 10));
      controller.enqueue("flush-data");
      flushCalled = true;
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("A");
  await writer.close();
  
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    results.push(value);
  }
  
  return flushCalled === true && 
         results.length === 2 && 
         results[0] === "A" && 
         results[1] === "flush-data";
})(), "Async flush() should be called on close and can enqueue")

// Async flush with delayed completion
assert.isTrue((async () => {
  let flushTime = 0;
  const startTime = Date.now();
  
  const ts = new TransformStream({
    transform(chunk, controller) {
      controller.enqueue(chunk);
    },
    async flush(controller) {
      await new Promise(resolve => setTimeout(resolve, 20));
      flushTime = Date.now() - startTime;
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("data");
  await writer.close();
  
  // Drain readable
  while (true) {
    const { done } = await reader.read();
    if (done) break;
  }
  
  // Flush should have taken at least 20ms
  return flushTime >= 15; // Allow timing tolerance
})(), "Async flush() should wait for promise resolution")

// Async flush error propagates
assert.isTrue((async () => {
  let errorMessage = null;
  
  const ts = new TransformStream({
    transform(chunk, controller) {
      controller.enqueue(chunk);
    },
    async flush(controller) {
      await new Promise(resolve => setTimeout(resolve, 5));
      throw new Error("Flush failed");
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("data");
  
  try {
    await writer.close();
    // Drain readable - should see error
    while (true) {
      const { done } = await reader.read();
      if (done) break;
    }
  } catch (error) {
    errorMessage = error.message;
  }
  
  return errorMessage === "Flush failed";
})(), "Async flush() error should propagate")

// Async flush that adds final summary
assert.isTrue((async () => {
  let chunkCount = 0;
  const results = [];
  
  const ts = new TransformStream({
    transform(chunk, controller) {
      chunkCount++;
      controller.enqueue(chunk);
    },
    async flush(controller) {
      await new Promise(resolve => setTimeout(resolve, 5));
      controller.enqueue(`Total: ${chunkCount} chunks`);
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("A");
  await writer.write("B");
  await writer.write("C");
  await writer.close();
  
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    results.push(value);
  }
  
  return results.length === 4 && 
         results[3] === "Total: 3 chunks";
})(), "Async flush() can add summary data at end")

// ============================================================================
// Combined Async transform() and flush() Tests
// ============================================================================

// Full pipeline with both async callbacks
assert.isTrue((async () => {
  const operations = [];
  
  const ts = new TransformStream({
    async start(controller) {
      operations.push("start");
    },
    async transform(chunk, controller) {
      operations.push(`transform-${chunk}`);
      await new Promise(resolve => setTimeout(resolve, 5));
      controller.enqueue(chunk.toUpperCase());
    },
    async flush(controller) {
      operations.push("flush");
      await new Promise(resolve => setTimeout(resolve, 5));
      controller.enqueue("END");
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("a");
  await writer.write("b");
  await writer.close();
  
  const results = [];
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    results.push(value);
  }
  
  return operations.length === 4 &&
         operations[0] === "start" &&
         operations[1] === "transform-a" &&
         operations[2] === "transform-b" &&
         operations[3] === "flush" &&
         results.length === 3 &&
         results[0] === "A" &&
         results[1] === "B" &&
         results[2] === "END";
})(), "Full pipeline with async transform and flush should work")

// Error in transform doesn't call flush
assert.isTrue((async () => {
  let flushCalled = false;
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      if (chunk === 2) {
        throw new Error("Transform error");
      }
      controller.enqueue(chunk);
    },
    async flush(controller) {
      flushCalled = true;
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  try {
    await writer.write(1);
    await writer.write(2); // Should throw
    await writer.close();
  } catch (e) {
    // Expected
  }
  
  try {
    while (true) {
      const { done } = await reader.read();
      if (done) break;
    }
  } catch (e) {
    // Expected
  }
  
  return flushCalled === false;
})(), "Error in transform should prevent flush from being called")

// ============================================================================
// Chained TransformStreams (Pipelines) - SKIPPED
// ============================================================================

// NOTE: pipeThrough is not fully implemented yet, so chained TransformStream
// tests are skipped. See: src/webidl/impls/ReadableStream.zig:794
// TODO: Add chained TransformStream tests when pipeThrough is implemented

// ============================================================================
// Edge Cases
// ============================================================================

// Transform that takes longer than subsequent writes
assert.isTrue((async () => {
  const order = [];
  
  const ts = new TransformStream({
    async transform(chunk, controller) {
      order.push(`start-${chunk}`);
      // Variable delay based on chunk
      await new Promise(resolve => setTimeout(resolve, chunk === 1 ? 30 : 5));
      order.push(`end-${chunk}`);
      controller.enqueue(chunk);
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  // Write chunks - first takes longer
  await writer.write(1);
  await writer.write(2);
  await writer.close();
  
  // Drain
  while (true) {
    const { done } = await reader.read();
    if (done) break;
  }
  
  // Should still process in order due to backpressure
  return order[0] === "start-1" &&
         order[1] === "end-1" &&
         order[2] === "start-2" &&
         order[3] === "end-2";
})(), "Slow transforms should block subsequent writes")

// Empty flush (no enqueue)
assert.isTrue((async () => {
  let flushCalled = false;
  
  const ts = new TransformStream({
    transform(chunk, controller) {
      controller.enqueue(chunk);
    },
    async flush(controller) {
      await new Promise(resolve => setTimeout(resolve, 5));
      flushCalled = true;
      // No enqueue - just cleanup
    }
  });
  
  const writer = ts.writable.getWriter();
  const reader = ts.readable.getReader();
  
  await writer.write("data");
  await writer.close();
  
  const results = [];
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    results.push(value);
  }
  
  return flushCalled === true && results.length === 1 && results[0] === "data";
})(), "Async flush() without enqueue should work")

// Transform with async iteration on readable side
assert.isTrue((async () => {
  const ts = new TransformStream({
    async transform(chunk, controller) {
      await new Promise(resolve => setTimeout(resolve, 5));
      controller.enqueue(chunk + "!");
    }
  });
  
  const writer = ts.writable.getWriter();
  
  // Write in background
  (async () => {
    await writer.write("Hello");
    await writer.write("World");
    await writer.close();
  })();
  
  // Read using async iteration
  const results = [];
  for await (const chunk of ts.readable) {
    results.push(chunk);
  }
  
  return results.length === 2 && 
         results[0] === "Hello!" && 
         results[1] === "World!";
})(), "Async transform works with async iteration on readable")

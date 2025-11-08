# Browser Benchmarking Skill

## Purpose

This skill provides guidance on how to benchmark the WHATWG Streams implementation against browser engines, identify optimization opportunities, and measure stream operation performance.

---

## Why Benchmark Against Browsers?

**Streams must match browser behavior** - both functionally AND performantly.

### Key Reasons

1. **Compatibility Verification**
   - Ensure stream operations match Chrome, Firefox, Safari
   - Validate backpressure handling
   - Confirm queuing behavior

2. **Performance Targets**
   - Set realistic performance goals based on browser implementations
   - Identify optimization opportunities
   - Avoid premature optimization (measure first!)

3. **Regression Detection**
   - Catch performance regressions early
   - Track improvements over time
   - Validate optimization effectiveness

---

## Streams Performance Characteristics

### What to Measure

| Operation | Why Measure | Browser Typical Performance |
|-----------|-------------|----------------------------|
| **Stream reading** | Core hot path | 0.5-2 μs per read |
| **Stream writing** | Frequent operation | 0.5-2 μs per write |
| **Chunk enqueueing** | Queue management | 0.1-0.5 μs per chunk |
| **Pipe operations** | Connecting streams | 2-10 μs per pipe setup |
| **Backpressure signaling** | Flow control | < 0.1 μs |
| **BYOB reading** | Zero-copy reads | 0.3-1 μs per read |

### Browser Streams Implementations

**Chromium (Blink)**:
- Location: `third_party/blink/renderer/core/streams/`
- Fast path for byte streams (Uint8Array)
- Optimized chunk queuing with ArrayDeque
- Inline storage for small queues

**Firefox (Gecko)**:
- Location: `dom/streams/`
- Lazy stream initialization
- Cached reader/writer objects
- Minimal allocations for backpressure signals

**WebKit**:
- Location: `Source/WebCore/Modules/streams/`
- Similar patterns to Chromium
- Fast paths for ReadableStream body responses

---

## Benchmarking Strategy

### 1. Microbenchmarks (Single Operation)

**Purpose**: Measure individual stream operations in isolation

**Example**:
```zig
test "benchmark - read from byte stream" {
    const allocator = std.testing.allocator;
    
    var stream = try ReadableStream.init(allocator, .{
        .pull = testPullFn,
    });
    defer stream.deinit();
    
    var timer = try std.time.Timer.start();
    const iterations = 100_000;
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const reader = try stream.getReader();
        defer reader.releaseLock();
        
        const result = try reader.read();
        if (result.value) |chunk| allocator.free(chunk);
    }
    
    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    
    std.debug.print("stream.read(): {} ns/op\n", .{ns_per_op});
    
    // Target: < 2000 ns (2 μs) per read for byte streams
    try std.testing.expect(ns_per_op < 2000);
}
```

### 2. Macro benchmarks (Real-World Scenarios)

**Purpose**: Measure realistic streaming workloads

**Examples**:
- Stream 1000 chunks through pipe chain
- Measure end-to-end transform stream processing
- Test backpressure under high load

### 3. Comparison Benchmarks (Against Browsers)

**Purpose**: Compare Zig performance to browser implementations

**Approach**:
```javascript
// JavaScript (run in browser)
console.time("read-100k-chunks");
const stream = new ReadableStream({
    pull(controller) {
        controller.enqueue(new Uint8Array([1, 2, 3, 4]));
    }
});
const reader = stream.getReader();
for (let i = 0; i < 100000; i++) {
    await reader.read();
}
console.timeEnd("read-100k-chunks");
```

Then compare against Zig implementation.

---

## Streams-Specific Optimization Opportunities

### 1. Byte Stream Fast Path

**Pattern**: Optimize for Uint8Array chunks (most common)

**Browser implementation** (Chromium):
```cpp
// Fast path for byte streams
if (stream->IsByteStream()) {
    return ReadByteStreamChunk(stream);
}
// Slow path for object streams
return ReadGenericChunk(stream);
```

**Zig implementation**:
```zig
/// Fast path for byte stream reading
pub fn read(self: *ReadableStreamDefaultReader) !ReadResult {
    const stream = self.stream;
    
    // Fast path: byte stream with queued data
    if (stream.isByteStream() and stream.queue.items.len > 0) {
        const chunk = stream.queue.orderedRemove(0);
        return ReadResult{ .done = false, .value = chunk };
    }
    
    // Slow path: object stream or empty queue
    return try readSlow(self);
}
```

**Benchmark**:
```zig
test "benchmark - byte stream reading" {
    const allocator = std.testing.allocator;
    
    var stream = try ReadableStream.initByteStream(allocator, .{
        .pull = bytePullFn,
    });
    defer stream.deinit();
    
    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        const encoded = try percentEncode(allocator, input, .path);
        defer allocator.free(encoded);
    }
    const elapsed = timer.read();
    std.debug.print("percentEncode: {} ns/op\n", .{elapsed / 100_000});
}
```

### 2. Chunk Queue Optimization

**Pattern**: Use inline storage for small queues

**Implementation**:
```zig
pub const StreamQueue = struct {
    // Inline storage for small queues (most common case)
    small_buffer: [4][]const u8,
    small_len: usize,
    // Heap storage for large queues
    large_buffer: ?std.ArrayList([]const u8),
    
    pub fn enqueue(self: *StreamQueue, chunk: []const u8) !void {
        // Fast path: use inline buffer
        if (self.small_len < 4 and self.large_buffer == null) {
            self.small_buffer[self.small_len] = chunk;
            self.small_len += 1;
            return;
        }
        
        // Slow path: spill to ArrayList
        if (self.large_buffer == null) {
            self.large_buffer = std.ArrayList([]const u8).init(allocator);
            for (self.small_buffer[0..self.small_len]) |item| {
                try self.large_buffer.?.append(item);
            }
        }
        try self.large_buffer.?.append(chunk);
    }
};
```

**Benchmark**:
```zig
test "benchmark - small vs large queue" {
    const allocator = std.testing.allocator;
    
    // Small queue (inline storage)
    var small_queue = StreamQueue.init();
    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        try small_queue.enqueue("chunk");
        _ = small_queue.dequeue();
    }
    const small_time = timer.read();
    
    // Large queue (ArrayList)
    var large_queue = StreamQueue.init();
    timer.reset();
    i = 0;
    while (i < 100_000) : (i += 1) {
        try large_queue.enqueue("chunk");
        if (i % 10 == 0) _ = large_queue.dequeue(); // Keep queue large
    }
    const large_time = timer.read();
    
    std.debug.print("Small queue: {} ns/op, Large queue: {} ns/op\n", 
        .{small_time / 100_000, large_time / 100_000});
    
    // Small queue should be faster
    try std.testing.expect(small_time < large_time);
}
```

### 3. Backpressure Signal Fast Path

**Pattern**: Quick boolean check before complex logic

**Implementation**:
```zig
pub fn getDesiredSize(self: *ReadableStream) f64 {
    // Fast path: no queue, return high water mark
    if (self.queue.items.len == 0) {
        return self.strategy.highWaterMark;
    }
    
    // Calculate queue size
    var queue_size: f64 = 0;
    for (self.queue.items) |chunk| {
        if (self.strategy.size) |size_fn| {
            queue_size += size_fn(chunk);
        } else {
            queue_size += 1;
        }
    }
    
    return self.strategy.highWaterMark - queue_size;
}

pub inline fn shouldApplyBackpressure(self: *ReadableStream) bool {
    return self.getDesiredSize() <= 0;
}
```

### 4. URL Serialization with Capacity Hints

**Pattern**: Preallocate buffer based on component sizes

**Implementation**:
```zig
pub fn serialize(self: *const URL, allocator: Allocator) ![]u8 {
    // Calculate minimum size needed
    var capacity: usize = 0;
    capacity += self.scheme.len + 1; // "scheme:"
    if (self.host) |host| {
        capacity += 2; // "//"
        capacity += estimateHostSize(host);
    }
    if (self.port) |_| {
        capacity += 6; // ":12345"
    }
    capacity += self.path.len;
    if (self.query) |q| capacity += 1 + q.len;
    if (self.fragment) |f| capacity += 1 + f.len;
    
    // Preallocate (avoids reallocation)
    var result = try std.ArrayList(u8).initCapacity(allocator, capacity);
    errdefer result.deinit();
    
    // Serialize components
    try result.appendSlice(self.scheme);
    try result.append(':');
    // ... (rest of serialization)
    
    return result.toOwnedSlice();
}
```

### 5. Special Scheme Fast Paths

**Pattern**: Optimize for common schemes (http, https, file)

**Implementation**:
```zig
pub fn parseURL(allocator: Allocator, input: []const u8) !URL {
    // Detect special schemes early
    const scheme = try extractScheme(input);
    
    if (isSpecialScheme(scheme)) {
        // Fast path for http, https, file, ftp, ws, wss
        return parseSpecialURL(allocator, input, scheme);
    } else {
        // Generic URL parsing
        return parseGenericURL(allocator, input, scheme);
    }
}

inline fn isSpecialScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "http") or
           std.mem.eql(u8, scheme, "https") or
           std.mem.eql(u8, scheme, "file") or
           std.mem.eql(u8, scheme, "ftp") or
           std.mem.eql(u8, scheme, "ws") or
           std.mem.eql(u8, scheme, "wss");
}
```

---

## Benchmarking Tools

### 1. Zig Built-in Timer

```zig
const std = @import("std");

pub fn benchmark(comptime name: []const u8, iterations: usize, func: anytype) !void {
    var timer = try std.time.Timer.start();
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        func();
    }
    
    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    
    std.debug.print("{s}: {} ns/op ({d:.2} μs/op)\n", 
        .{name, ns_per_op, @as(f64, @floatFromInt(ns_per_op)) / 1000.0});
}
```

### 2. Browser DevTools (for comparison)

**Chrome DevTools**:
```javascript
// Microbenchmark
console.time("parse-url");
for (let i = 0; i < 100000; i++) {
    new URL("https://example.com/path?query#fragment");
}
console.timeEnd("parse-url");

// Detailed profiling
performance.mark("start");
for (let i = 0; i < 100000; i++) {
    new URL("https://example.com/path?query#fragment");
}
performance.mark("end");
performance.measure("url-parse", "start", "end");
console.log(performance.getEntriesByName("url-parse"));
```

### 3. Criterion-like Benchmarking

```zig
// Simple benchmark suite
pub const BenchmarkSuite = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) BenchmarkSuite {
        return .{ .allocator = allocator };
    }
    
    pub fn run(self: BenchmarkSuite, comptime name: []const u8, func: anytype) !void {
        const iterations = 100_000;
        var timer = try std.time.Timer.start();
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            try func(self.allocator);
        }
        
        const elapsed = timer.read();
        const ns_per_op = elapsed / iterations;
        
        std.debug.print("{s}: {} ns/op\n", .{name, ns_per_op});
    }
};

// Usage
test "benchmark suite" {
    var suite = BenchmarkSuite.init(std.testing.allocator);
    
    try suite.run("parse-simple-url", parseSimpleURL);
    try suite.run("parse-complex-url", parseComplexURL);
    try suite.run("parse-relative-url", parseRelativeURL);
}
```

---

## Real-World URL Datasets

### Test Against Real URLs

**Alexa Top 1000**:
- Download real-world URLs
- Parse each one
- Measure aggregate performance

**Example dataset**:
```
https://www.google.com
https://www.youtube.com
https://www.facebook.com
https://www.amazon.com
https://www.wikipedia.org
...
```

**Benchmark**:
```zig
test "benchmark - real-world URLs" {
    const urls = @embedFile("../data/alexa-top-1000.txt");
    var lines = std.mem.split(u8, urls, "\n");
    
    var timer = try std.time.Timer.start();
    var count: usize = 0;
    
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        
        const url = try URL.parse(allocator, line);
        defer url.deinit();
        count += 1;
    }
    
    const elapsed = timer.read();
    const ns_per_url = elapsed / count;
    
    std.debug.print("Parsed {} real URLs: {} ns/op\n", .{count, ns_per_url});
}
```

---

## Performance Targets

### Realistic Goals (Based on Browser Performance)

| Operation | Target | Notes |
|-----------|--------|-------|
| **Stream read** | < 2 μs | Byte stream reading |
| **Stream write** | < 2 μs | Byte stream writing |
| **Chunk enqueue** | < 500 ns | Adding to queue |
| **Chunk dequeue** | < 500 ns | Removing from queue |
| **Pipe setup** | < 10 μs | Connecting streams |
| **Backpressure check** | < 100 ns | getDesiredSize() |
| **BYOB read** | < 1 μs | Zero-copy reading |

**Note**: These are approximate targets. Actual browser performance varies by:
- CPU architecture
- Compiler optimizations
- Chunk characteristics (size, type)

---

## Avoiding Premature Optimization

### Optimization Workflow

1. **Implement correctly first**
   - Follow WHATWG Streams spec exactly
   - Pass all tests
   - Ensure spec compliance

2. **Measure baseline**
   - Benchmark current implementation
   - Identify hot spots with profiling
   - Set realistic targets

3. **Optimize hot paths**
   - Focus on frequently-called operations
   - Measure before and after
   - Verify correctness still holds

4. **Validate improvements**
   - Re-run full test suite
   - Compare against browsers
   - Check for regressions

### Red Flags (Don't Optimize Yet)

- ❌ No baseline measurements
- ❌ No clear performance problem
- ❌ Tests don't pass
- ❌ Spec compliance uncertain

### Green Lights (OK to Optimize)

- ✅ Tests pass (100% coverage)
- ✅ Spec compliant
- ✅ Baseline measured
- ✅ Clear bottleneck identified

---

## Integration with Other Skills

### With whatwg_spec

- Read `specs/url.md` to understand algorithm complexity
- Identify optimization opportunities in spec algorithms
- Ensure optimizations don't break spec compliance

### With testing_requirements

- Write performance regression tests
- Ensure optimizations pass all functional tests
- Add benchmark tests for critical paths

### With performance_optimization

- Apply general Zig optimization patterns
- Use lookup tables, fast paths, inline functions
- Minimize allocations

---

## Summary

**Key Principles:**

1. **Measure before optimizing** - Get baseline performance
2. **Compare against browsers** - Set realistic targets
3. **Focus on hot paths** - URL parsing, host parsing, percent encoding
4. **Use lookup tables** - Avoid range checks
5. **Fast path for ASCII** - Most URLs are ASCII-only
6. **Preallocate buffers** - Avoid reallocation
7. **Verify correctness** - Never sacrifice spec compliance for speed

**Workflow:**
1. Implement correctly (spec-compliant)
2. Measure baseline
3. Identify bottlenecks
4. Optimize hot paths
5. Verify improvements
6. Compare against browsers

**Remember**: URL parsing must match browser behavior. Performance matters, but correctness comes first.

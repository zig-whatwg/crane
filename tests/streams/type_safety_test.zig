//! Type Safety Tests for Streams Refactoring
//!
//! Comprehensive tests to verify that type safety is maintained throughout the
//! streams implementation after refactoring to eliminate unnecessary anyopaque usage.
//!
//! ## Test Categories
//!
//! 1. TypedChainConfig - Type-safe promise chaining configuration
//! 2. TypedAlgorithm generics - Compile-time typed algorithm contexts
//! 3. createTyped*Algorithm helpers - Type-safe algorithm creation
//! 4. Callback type safety - Proper context typing in callbacks
//! 5. JSValue type variants - No v8_value anyopaque misuse
//!
//! ## Design Philosophy
//!
//! These tests verify that:
//! - Compile-time type information is preserved through the call chain
//! - FFI boundaries are clearly marked and documented
//! - Type erasure only happens at documented FFI points
//! - Callbacks receive correctly typed contexts
//!
//! ## NOTE ON anyopaque IN THESE TESTS
//!
//! The test "Typed callback with type erasure and recovery" intentionally demonstrates
//! the anyopaque type erasure/recovery pattern. This is EDUCATIONAL - showing how
//! FFI boundaries work and why TypedAlgorithm exists to eliminate manual casting.
//! The TypedAlgorithm.erase() method encapsulates this pattern safely.

const std = @import("std");
const testing = std.testing;

// Import streams internal modules via build system dependencies
// These are defined in build.zig and made available to test modules
const common = @import("streams_common");

// Note: v8_promise_chaining tests are included inline in v8_promise_chaining.zig itself
// because it requires V8 FFI types that aren't available in the test context.
// The TypedChainConfig tests here use a simplified approach.

// ============================================================================
// Type-Safe Callback Pattern Tests
// ============================================================================
//
// Note: TypedChainConfig tests are in v8_promise_chaining.zig itself since they
// require V8 FFI types. These tests demonstrate the general callback typing pattern.

test "Typed callback pattern - context preservation" {
    // This pattern is used throughout streams for type-safe callbacks
    const TestContext = struct {
        value: i32,
        name: []const u8,

        fn callback(self: *@This()) void {
            self.value += 1;
        }
    };

    var context = TestContext{ .value = 42, .name = "test" };

    // Type-safe callback invocation
    context.callback();
    try testing.expectEqual(@as(i32, 43), context.value);
    try testing.expectEqualStrings("test", context.name);
}

test "Typed callback with type erasure and recovery" {
    const Counter = struct {
        count: usize = 0,

        fn increment(self: *@This()) void {
            self.count += 1;
        }
    };

    var counter = Counter{};

    // Simulate type erasure (what happens at FFI boundary)
    const erased_ptr: *anyopaque = &counter;

    // Simulate type recovery in callback
    const recovered: *Counter = @ptrCast(@alignCast(erased_ptr));
    recovered.increment();

    try testing.expectEqual(@as(usize, 1), counter.count);
}

// ============================================================================
// TypedAlgorithm Generic Tests (from common.zig)
// ============================================================================

test "TypedAlgorithm - maintains type through call chain" {
    const Counter = struct {
        calls: usize = 0,
        last_value: i32 = 0,

        fn increment(self: *@This()) i32 {
            self.calls += 1;
            self.last_value = @intCast(self.calls);
            return self.last_value;
        }
    };

    var counter = Counter{};

    // Create typed algorithm (Context type is Counter, so context param is *Counter)
    const algo = common.TypedAlgorithm(Counter, i32).init(
        &counter,
        struct {
            fn call(ctx: *Counter) i32 {
                return ctx.increment();
            }
        }.call,
        null,
    );

    // Call maintains type safety
    const result1 = algo.call();
    try testing.expectEqual(@as(i32, 1), result1);
    try testing.expectEqual(@as(usize, 1), counter.calls);

    const result2 = algo.call();
    try testing.expectEqual(@as(i32, 2), result2);
    try testing.expectEqual(@as(usize, 2), counter.calls);
}

test "TypedAlgorithm.erase - type erasure for polymorphism" {
    const State = struct {
        value: u64,
    };

    var state = State{ .value = 100 };

    const typed = common.TypedAlgorithm(State, u64).init(
        &state,
        struct {
            fn call(ctx: *State) u64 {
                return ctx.value;
            }
        }.call,
        null,
    );

    // Erase to polymorphic form
    const erased = typed.erase();

    // Erased version still works (through anyopaque)
    const result = erased.call();
    try testing.expectEqual(@as(u64, 100), result);
}

test "TypedAlgorithmWithArg - typed argument passing" {
    const Accumulator = struct {
        total: i64 = 0,

        fn add(self: *@This(), value: i64) i64 {
            self.total += value;
            return self.total;
        }
    };

    var acc = Accumulator{};

    const algo = common.TypedAlgorithmWithArg(Accumulator, i64, i64).init(
        &acc,
        struct {
            fn call(ctx: *Accumulator, arg: i64) i64 {
                return ctx.add(arg);
            }
        }.call,
        null,
    );

    // Arguments maintain their types
    try testing.expectEqual(@as(i64, 10), algo.call(10));
    try testing.expectEqual(@as(i64, 25), algo.call(15));
    try testing.expectEqual(@as(i64, 25), acc.total);
}

// ============================================================================
// createTyped*Algorithm Helper Tests
// ============================================================================

test "createTypedTransformAlgorithm - type-safe transform creation" {
    const Transformer = struct {
        multiplier: f64,
        call_count: usize = 0,

        fn transform(self: *@This(), _: common.JSValue) common.Promise(void) {
            self.call_count += 1;
            _ = self.multiplier; // Type-safe access
            return common.Promise(void).fulfilled({});
        }
    };

    var transformer = Transformer{ .multiplier = 2.5 };

    const algo = common.createTypedTransformAlgorithm(
        Transformer,
        &transformer,
        Transformer.transform,
        null,
    );

    // Call the algorithm
    const result = algo.call(common.JSValue.undefined_value());
    try testing.expect(result.isFulfilled());
    try testing.expectEqual(@as(usize, 1), transformer.call_count);
}

test "createTypedFlushAlgorithm - type-safe flush creation" {
    const Flusher = struct {
        flushed: bool = false,

        fn flush(self: *@This()) common.Promise(void) {
            self.flushed = true;
            return common.Promise(void).fulfilled({});
        }
    };

    var flusher = Flusher{};

    const algo = common.createTypedFlushAlgorithm(
        Flusher,
        &flusher,
        Flusher.flush,
        null,
    );

    try testing.expect(!flusher.flushed);
    _ = algo.call();
    try testing.expect(flusher.flushed);
}

test "createTypedCancelAlgorithm - type-safe cancel with reason" {
    const Canceller = struct {
        cancelled: bool = false,
        reason_received: bool = false,

        fn cancel(self: *@This(), reason: ?common.JSValue) common.Promise(void) {
            self.cancelled = true;
            self.reason_received = reason != null;
            return common.Promise(void).fulfilled({});
        }
    };

    var canceller = Canceller{};

    const algo = common.createTypedCancelAlgorithm(
        Canceller,
        &canceller,
        Canceller.cancel,
        null,
    );

    // Cancel with reason
    _ = algo.call(common.JSValue{ .string = "user cancelled" });
    try testing.expect(canceller.cancelled);
    try testing.expect(canceller.reason_received);
}

test "createTypedPullAlgorithm - type-safe pull creation" {
    const Puller = struct {
        pulls: usize = 0,

        fn pull(self: *@This()) common.Promise(void) {
            self.pulls += 1;
            return common.Promise(void).fulfilled({});
        }
    };

    var puller = Puller{};

    const algo = common.createTypedPullAlgorithm(
        Puller,
        &puller,
        Puller.pull,
        null,
    );

    _ = algo.call();
    _ = algo.call();
    try testing.expectEqual(@as(usize, 2), puller.pulls);
}

test "createTypedWriteAlgorithm - type-safe write with chunk" {
    const Writer = struct {
        chunks_written: usize = 0,

        fn write(self: *@This(), _: common.JSValue) common.Promise(void) {
            self.chunks_written += 1;
            return common.Promise(void).fulfilled({});
        }
    };

    var writer = Writer{};

    const algo = common.createTypedWriteAlgorithm(
        Writer,
        &writer,
        Writer.write,
        null,
    );

    _ = algo.call(common.JSValue{ .number = 42 });
    _ = algo.call(common.JSValue{ .string = "hello" });
    try testing.expectEqual(@as(usize, 2), writer.chunks_written);
}

test "createTypedStartAlgorithm - type-safe start creation" {
    const Starter = struct {
        started: bool = false,

        fn start(self: *@This()) common.Promise(void) {
            self.started = true;
            return common.Promise(void).fulfilled({});
        }
    };

    var starter = Starter{};

    const algo = common.createTypedStartAlgorithm(
        Starter,
        &starter,
        Starter.start,
        null,
    );

    try testing.expect(!starter.started);
    _ = algo.call();
    try testing.expect(starter.started);
}

test "createTypedSizeAlgorithm - type-safe size calculation" {
    const Sizer = struct {
        fixed_size: f64,

        fn size(self: *@This(), _: common.JSValue) f64 {
            return self.fixed_size;
        }
    };

    var sizer = Sizer{ .fixed_size = 42.5 };

    const algo = common.createTypedSizeAlgorithm(
        Sizer,
        &sizer,
        Sizer.size,
        null,
    );

    const size = algo.call(common.JSValue.undefined_value());
    try testing.expectEqual(@as(f64, 42.5), size);
}

// ============================================================================
// TypedReadCallbacks Tests
// ============================================================================

test "TypedReadCallbacks - type-safe read request callbacks" {
    const ReadContext = struct {
        chunks_received: usize = 0,
        closed: bool = false,
        error_received: bool = false,

        fn onChunk(self: *@This(), _: common.JSValue) void {
            self.chunks_received += 1;
        }

        fn onClose(self: *@This()) void {
            self.closed = true;
        }

        fn onError(self: *@This(), _: common.JSValue) void {
            self.error_received = true;
        }
    };

    var ctx = ReadContext{};

    const callbacks = common.TypedReadCallbacks(ReadContext){
        .context = &ctx,
        .chunk_steps = ReadContext.onChunk,
        .close_steps = ReadContext.onClose,
        .error_steps = ReadContext.onError,
    };

    // Execute callbacks with type safety
    callbacks.executeChunkSteps(common.JSValue{ .number = 1 });
    callbacks.executeChunkSteps(common.JSValue{ .number = 2 });
    try testing.expectEqual(@as(usize, 2), ctx.chunks_received);

    callbacks.executeCloseSteps();
    try testing.expect(ctx.closed);
}

test "TypedReadCallbacks.erase - polymorphic storage" {
    const SimpleContext = struct {
        value: i32 = 0,

        fn onChunk(self: *@This(), _: common.JSValue) void {
            self.value += 1;
        }
        fn onClose(_: *@This()) void {}
        fn onError(_: *@This(), _: common.JSValue) void {}
    };

    var ctx = SimpleContext{};

    const typed = common.TypedReadCallbacks(SimpleContext){
        .context = &ctx,
        .chunk_steps = SimpleContext.onChunk,
        .close_steps = SimpleContext.onClose,
        .error_steps = SimpleContext.onError,
    };

    // Erase for polymorphic storage
    const erased = typed.erase();

    // Erased callbacks still work
    erased.executeChunkSteps(common.JSValue.undefined_value());
    try testing.expectEqual(@as(i32, 1), ctx.value);
}

// ============================================================================
// JSValue Type Safety Tests
// ============================================================================

test "JSValue - union variants preserve type information" {
    // Test each variant maintains its type
    const undefined_val = common.JSValue.undefined_value();
    try testing.expect(undefined_val == .undefined);

    const null_val = common.JSValue{ .null = {} };
    try testing.expect(null_val == .null);

    const bool_val = common.JSValue{ .boolean = true };
    try testing.expect(bool_val == .boolean);
    try testing.expect(bool_val.boolean);

    const num_val = common.JSValue{ .number = 3.14 };
    try testing.expect(num_val == .number);
    try testing.expectEqual(@as(f64, 3.14), num_val.number);

    const str_val = common.JSValue{ .string = "hello" };
    try testing.expect(str_val == .string);
    try testing.expectEqualStrings("hello", str_val.string);
}

test "JSValue.createError - creates properly typed error" {
    const error_val = common.JSValue.createError("test error");
    try testing.expect(error_val == .error_value);
    try testing.expect(error_val.isError());
    try testing.expectEqual(common.ErrorType.generic, error_val.getErrorType().?);
    try testing.expectEqualStrings("test error", error_val.getErrorMessage().?);
}

// ============================================================================
// Promise Type Safety Tests
// ============================================================================

test "Promise - type-safe state transitions" {
    // Pending promise
    var promise = common.Promise(i32).pending();
    try testing.expect(promise.isPending());
    try testing.expect(!promise.isFulfilled());
    try testing.expect(!promise.isRejected());

    // Fulfill with typed value
    promise.fulfill(42);
    try testing.expect(promise.isFulfilled());
    try testing.expectEqual(@as(?i32, 42), promise.value);
}

test "Promise(void) - unit type promise" {
    const fulfilled = common.Promise(void).fulfilled({});
    try testing.expect(fulfilled.isFulfilled());

    const pending = common.Promise(void).pending();
    try testing.expect(pending.isPending());
}

// ============================================================================
// Deinit/Cleanup Type Safety Tests
// ============================================================================

test "TypedAlgorithm - deinit receives typed context" {
    const Resource = struct {
        allocator: std.mem.Allocator,
        data: []u8,
        cleanup_called: *bool,

        fn deinitSelf(self: *@This()) void {
            self.cleanup_called.* = true;
            self.allocator.free(self.data);
        }
    };

    var cleanup_called = false;
    const data = try testing.allocator.alloc(u8, 10);

    var resource = Resource{
        .allocator = testing.allocator,
        .data = data,
        .cleanup_called = &cleanup_called,
    };

    const algo = common.TypedAlgorithm(Resource, void).init(
        &resource,
        struct {
            fn call(_: *Resource) void {}
        }.call,
        struct {
            fn deinitFn(ctx: *Resource) void {
                ctx.deinitSelf();
            }
        }.deinitFn,
    );

    try testing.expect(!cleanup_called);
    algo.deinit();
    try testing.expect(cleanup_called);
}

// ============================================================================
// Integration Tests - Full Flow Type Safety
// ============================================================================

test "Integration - typed algorithm creation and invocation flow" {
    // Simulate a transform stream setup with type-safe algorithms

    const TransformState = struct {
        transform_calls: usize = 0,
        flush_calls: usize = 0,
        cancel_calls: usize = 0,

        fn transform(self: *@This(), _: common.JSValue) common.Promise(void) {
            self.transform_calls += 1;
            return common.Promise(void).fulfilled({});
        }

        fn flush(self: *@This()) common.Promise(void) {
            self.flush_calls += 1;
            return common.Promise(void).fulfilled({});
        }

        fn cancel(self: *@This(), _: ?common.JSValue) common.Promise(void) {
            self.cancel_calls += 1;
            return common.Promise(void).fulfilled({});
        }
    };

    var state = TransformState{};

    // Create all algorithms with type safety
    const transform_algo = common.createTypedTransformAlgorithm(
        TransformState,
        &state,
        TransformState.transform,
        null,
    );
    const flush_algo = common.createTypedFlushAlgorithm(
        TransformState,
        &state,
        TransformState.flush,
        null,
    );
    const cancel_algo = common.createTypedCancelAlgorithm(
        TransformState,
        &state,
        TransformState.cancel,
        null,
    );

    // Simulate transform stream operations
    _ = transform_algo.call(common.JSValue{ .string = "chunk1" });
    _ = transform_algo.call(common.JSValue{ .string = "chunk2" });
    _ = flush_algo.call();

    try testing.expectEqual(@as(usize, 2), state.transform_calls);
    try testing.expectEqual(@as(usize, 1), state.flush_calls);
    try testing.expectEqual(@as(usize, 0), state.cancel_calls);

    // Simulate cancel
    _ = cancel_algo.call(common.JSValue{ .string = "aborted" });
    try testing.expectEqual(@as(usize, 1), state.cancel_calls);
}

test "Integration - readable stream pull loop type safety" {
    const PullState = struct {
        items: []const i32,
        index: usize = 0,

        fn pull(self: *@This()) common.Promise(void) {
            if (self.index < self.items.len) {
                self.index += 1;
            }
            return common.Promise(void).fulfilled({});
        }
    };

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var state = PullState{ .items = &items };

    const pull_algo = common.createTypedPullAlgorithm(
        PullState,
        &state,
        PullState.pull,
        null,
    );

    // Simulate pull loop
    while (state.index < items.len) {
        _ = pull_algo.call();
    }

    try testing.expectEqual(@as(usize, 5), state.index);
}

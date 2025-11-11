//! Common types and utilities shared across the Streams implementation
//!
//! This module provides placeholder types that will eventually be replaced
//! by actual webidl types when full integration is complete.

const std = @import("std");
const webidl = @import("webidl");

/// Internal JSValue type (simplified from webidl.JSValue)
/// Used for internal algorithms - bridges to webidl.JSValue at public boundaries
pub const JSValue = union(enum) {
    undefined: void,
    null: void,
    boolean: bool,
    number: f64,
    string: []const u8,
    bytes: []const u8,
    object: void,
    /// Close sentinel - unique value for WritableStream close signaling
    /// Spec: § 3.9.17 "The close sentinel is a unique value enqueued into [[queue]]"
    close_sentinel: void,

    pub fn undefined_value() JSValue {
        return .undefined;
    }

    pub fn null_value() JSValue {
        return .null;
    }

    pub fn closeSentinel() JSValue {
        return .close_sentinel;
    }

    pub fn isCloseSentinel(self: JSValue) bool {
        return self == .close_sentinel;
    }

    /// Convert from webidl.JSValue to internal JSValue
    /// This is a temporary bridge until full webidl integration
    pub fn fromWebIDL(value: webidl.JSValue) JSValue {
        return switch (value) {
            .undefined => .undefined,
            .null => .null,
            .boolean => |b| .{ .boolean = b },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = s },
            // TODO: Handle more types properly
            else => .undefined,
        };
    }

    /// Convert internal JSValue to webidl.JSValue
    /// This is a temporary bridge until full webidl integration
    pub fn toWebIDL(self: JSValue) webidl.JSValue {
        return switch (self) {
            .undefined => .{ .undefined = {} },
            .null => .{ .null = {} },
            .boolean => |b| .{ .boolean = b },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = s },
            .bytes, .object => .{ .undefined = {} }, // Bytes/objects as undefined for now
            .close_sentinel => .{ .undefined = {} }, // Close sentinel never exposed to web
        };
    }

    /// Convert JSValue to webidl.errors.Exception
    /// Used when rejecting promises - converts error values to proper exceptions
    pub fn toException(self: JSValue, allocator: std.mem.Allocator) !webidl.errors.Exception {
        return switch (self) {
            .string => |s| try webidl.errors.Exception.fromString(allocator, s),
            else => try webidl.errors.Exception.typeError(allocator, "Unknown error"),
        };
    }
};

/// Placeholder for Promise type
/// In production, this will be webidl.Promise(T)
///
/// Error Handling:
/// - Promises can be rejected with proper WebIDL exceptions (TypeError, RangeError, DOMException)
/// - This enables correct error propagation to JavaScript runtimes
/// - For user-provided rejection reasons (e.g., cancel reasons), those remain as JSValue
pub fn Promise(comptime T: type) type {
    return struct {
        state: State = .pending,
        value: ?T = null,
        error_value: ?webidl.errors.Exception = null,

        const Self = @This();

        pub const State = enum {
            pending,
            fulfilled,
            rejected,
        };

        pub fn pending() Self {
            return .{ .state = .pending };
        }

        pub fn fulfilled(value: T) Self {
            return .{
                .state = .fulfilled,
                .value = value,
            };
        }

        pub fn rejected(err: webidl.errors.Exception) Self {
            return .{
                .state = .rejected,
                .error_value = err,
            };
        }

        pub fn fulfill(self: *Self, value: T) void {
            self.state = .fulfilled;
            self.value = value;
        }

        pub fn reject(self: *Self, err: webidl.errors.Exception) void {
            self.state = .rejected;
            self.error_value = err;
        }

        pub fn isPending(self: *const Self) bool {
            return self.state == .pending;
        }

        pub fn isFulfilled(self: *const Self) bool {
            return self.state == .fulfilled;
        }

        pub fn isRejected(self: *const Self) bool {
            return self.state == .rejected;
        }
    };
}

/// ReadableStreamReadResult dictionary
/// Represents the result of a read operation
pub const ReadResult = struct {
    /// The value read (if not done)
    value: ?JSValue,
    /// Whether the stream is done (closed)
    done: bool,
};

/// Algorithm function types for stream operations
///
/// These use a VTable pattern (like std.mem.Allocator) to support context passing.
/// This enables stateful algorithms (e.g., TeeState coordination, TransformStream transforms)
/// while maintaining runtime polymorphism.
///
/// Design: See ALGORITHM_CONTEXT_DESIGN.md
/// Start algorithm - called once when stream is initialized
/// Spec: Abstract operation passed to SetUpReadableStreamDefaultController/SetUpReadableByteStreamController
pub const StartAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: StartAlgorithm) Promise(void) {
        return self.vtable.call(self.ptr);
    }

    pub fn deinit(self: StartAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Pull algorithm - called when controller needs data
/// Spec: Abstract operation passed to SetUpReadableStreamDefaultController
pub const PullAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    /// Call the pull algorithm
    pub fn call(self: PullAlgorithm) Promise(void) {
        return self.vtable.call(self.ptr);
    }

    /// Cleanup resources (if needed)
    pub fn deinit(self: PullAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Cancel algorithm - called when stream is canceled
/// Spec: Abstract operation passed to SetUpReadableStreamDefaultController
pub const CancelAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque, reason: ?JSValue) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: CancelAlgorithm, reason: ?JSValue) Promise(void) {
        return self.vtable.call(self.ptr, reason);
    }

    pub fn deinit(self: CancelAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Size algorithm - calculates chunk size
/// Spec: Abstract operation for queuing strategies
pub const SizeAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque, chunk: JSValue) f64,
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: SizeAlgorithm, chunk: JSValue) f64 {
        return self.vtable.call(self.ptr, chunk);
    }

    pub fn deinit(self: SizeAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Write algorithm - writes a chunk
/// Spec: Abstract operation passed to SetUpWritableStreamDefaultController
pub const WriteAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque, chunk: JSValue) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: WriteAlgorithm, chunk: JSValue) Promise(void) {
        return self.vtable.call(self.ptr, chunk);
    }

    pub fn deinit(self: WriteAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Close algorithm - closes the stream
/// Spec: Abstract operation passed to SetUpWritableStreamDefaultController
pub const CloseAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: CloseAlgorithm) Promise(void) {
        return self.vtable.call(self.ptr);
    }

    pub fn deinit(self: CloseAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Abort algorithm - aborts the stream
/// Spec: Abstract operation passed to SetUpWritableStreamDefaultController
pub const AbortAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque, reason: ?JSValue) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: AbortAlgorithm, reason: ?JSValue) Promise(void) {
        return self.vtable.call(self.ptr, reason);
    }

    pub fn deinit(self: AbortAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Flush algorithm - flushes the transform stream
/// Spec: Abstract operation passed to SetUpTransformStreamDefaultController
pub const FlushAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: FlushAlgorithm) Promise(void) {
        return self.vtable.call(self.ptr);
    }

    pub fn deinit(self: FlushAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Transform algorithm - transforms a chunk
/// Spec: Abstract operation passed to SetUpTransformStreamDefaultController
pub const TransformAlgorithm = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        call: *const fn (ctx: *anyopaque, chunk: JSValue) Promise(void),
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    pub fn call(self: TransformAlgorithm, chunk: JSValue) Promise(void) {
        return self.vtable.call(self.ptr, chunk);
    }

    pub fn deinit(self: TransformAlgorithm) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Iterator result from async iteration
/// Spec: ECMAScript IteratorResult interface { value, done }
pub const IteratorResult = struct {
    value: JSValue,
    done: bool,
};

/// Async Iterator protocol interface
/// Spec: ECMAScript Symbol.asyncIterator protocol
///
/// This represents the minimal interface for async iteration needed for ReadableStream.from()
pub const AsyncIterator = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// next() method - returns a promise of IteratorResult
        /// Spec: IteratorNext abstract operation
        next: *const fn (ctx: *anyopaque) Promise(IteratorResult),
        /// return() method - optional cleanup when iteration stops early
        /// Spec: IteratorReturn abstract operation
        return_fn: ?*const fn (ctx: *anyopaque, reason: ?JSValue) Promise(JSValue),
        /// Cleanup function
        deinit: ?*const fn (ctx: *anyopaque) void,
    };

    /// Call next() to get the next value
    pub fn next(self: AsyncIterator) Promise(IteratorResult) {
        return self.vtable.next(self.ptr);
    }

    /// Call return() to cleanup early termination
    pub fn return_value(self: AsyncIterator, reason: ?JSValue) ?Promise(JSValue) {
        if (self.vtable.return_fn) |return_fn| {
            return return_fn(self.ptr, reason);
        }
        return null;
    }

    /// Cleanup resources
    pub fn deinit(self: AsyncIterator) void {
        if (self.vtable.deinit) |deinit_fn| {
            deinit_fn(self.ptr);
        }
    }
};

/// Default algorithms that do nothing (for streams without custom behavior)
pub fn defaultPullAlgorithm() PullAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque) Promise(void) {
            _ = ctx;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined, // No context needed for default
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultCancelAlgorithm() CancelAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, reason: ?JSValue) Promise(void) {
            _ = ctx;
            _ = reason;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultSizeAlgorithm() SizeAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, chunk: JSValue) f64 {
            _ = ctx;
            _ = chunk;
            return 1.0;
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultWriteAlgorithm() WriteAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, chunk: JSValue) Promise(void) {
            _ = ctx;
            _ = chunk;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultCloseAlgorithm() CloseAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque) Promise(void) {
            _ = ctx;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultAbortAlgorithm() AbortAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, reason: ?JSValue) Promise(void) {
            _ = ctx;
            _ = reason;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultTransformAlgorithm() TransformAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, chunk: JSValue) Promise(void) {
            _ = ctx;
            _ = chunk;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn defaultFlushAlgorithm() FlushAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque) Promise(void) {
            _ = ctx;
            return Promise(void).fulfilled({});
        }
    };

    return .{
        .ptr = undefined,
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

/// Helper functions to wrap bare function pointers from WebIDL dictionaries
/// into algorithm structs
pub fn wrapPullCallback(callback_fn: *const fn () Promise(void)) PullAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque) Promise(void) {
            const func: *const fn () Promise(void) = @ptrCast(@alignCast(ctx));
            return func();
        }
    };

    return .{
        .ptr = @ptrCast(@constCast(callback_fn)),
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn wrapCancelCallback(callback_fn: *const fn (reason: ?JSValue) Promise(void)) CancelAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, reason: ?JSValue) Promise(void) {
            const func: *const fn (reason: ?JSValue) Promise(void) = @ptrCast(@alignCast(ctx));
            return func(reason);
        }
    };

    return .{
        .ptr = @ptrCast(@constCast(callback_fn)),
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn wrapSizeCallback(callback_fn: *const fn (chunk: JSValue) f64) SizeAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, chunk: JSValue) f64 {
            const func: *const fn (chunk: JSValue) f64 = @ptrCast(@alignCast(ctx));
            return func(chunk);
        }
    };

    return .{
        .ptr = @ptrCast(@constCast(callback_fn)),
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

/// Wrap webidl.GenericCallback as a SizeAlgorithm
///
/// This bridges webidl's callback system with the internal SizeAlgorithm abstraction.
/// The GenericCallback will be invoked through its vtable when size calculation is needed.
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default algorithm (size 1) since we can't invoke JS callbacks yet.
pub fn wrapGenericSizeCallback(callback: webidl.GenericCallback) SizeAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    // For now, store the callback but return size 1 (same as default)
    _ = callback;
    return defaultSizeAlgorithm();
}

pub fn wrapWriteCallback(callback_fn: *const fn (chunk: JSValue) Promise(void)) WriteAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, chunk: JSValue) Promise(void) {
            const func: *const fn (chunk: JSValue) Promise(void) = @ptrCast(@alignCast(ctx));
            return func(chunk);
        }
    };

    return .{
        .ptr = @ptrCast(@constCast(callback_fn)),
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn wrapCloseCallback(callback_fn: *const fn () Promise(void)) CloseAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque) Promise(void) {
            const func: *const fn () Promise(void) = @ptrCast(@alignCast(ctx));
            return func();
        }
    };

    return .{
        .ptr = @ptrCast(@constCast(callback_fn)),
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

pub fn wrapAbortCallback(callback_fn: *const fn (reason: ?JSValue) Promise(void)) AbortAlgorithm {
    const impl = struct {
        fn call(ctx: *anyopaque, reason: ?JSValue) Promise(void) {
            const func: *const fn (reason: ?JSValue) Promise(void) = @ptrCast(@alignCast(ctx));
            return func(reason);
        }
    };

    return .{
        .ptr = @ptrCast(@constCast(callback_fn)),
        .vtable = &.{
            .call = impl.call,
            .deinit = null,
        },
    };
}

/// Wrap webidl.GenericCallback as a CancelAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op cancel algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericCancelCallback(callback: webidl.GenericCallback) CancelAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultCancelAlgorithm();
}

/// Wrap webidl.GenericCallback as an AbortAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op abort algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericAbortCallback(callback: webidl.GenericCallback) AbortAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultAbortAlgorithm();
}

/// Wrap webidl.GenericCallback as a PullAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op pull algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericPullCallback(callback: webidl.GenericCallback) PullAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultPullAlgorithm();
}

/// Wrap webidl.GenericCallback as a CloseAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op close algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericCloseCallback(callback: webidl.GenericCallback) CloseAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultCloseAlgorithm();
}

/// Wrap webidl.GenericCallback as a WriteAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op write algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericWriteCallback(callback: webidl.GenericCallback) WriteAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultWriteAlgorithm();
}

/// Wrap webidl.GenericCallback as a TransformAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/pass-through transform algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericTransformCallback(callback: webidl.GenericCallback) TransformAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultTransformAlgorithm();
}

/// Wrap webidl.GenericCallback as a FlushAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op flush algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericFlushCallback(callback: webidl.GenericCallback) FlushAlgorithm {
    // TODO: Implement actual callback invocation when zig-js-runtime is available
    _ = callback;
    return defaultFlushAlgorithm();
}

// Tests

test "JSValue - basic types" {
    const undef = JSValue.undefined_value();
    const null_val = JSValue.null_value();
    const num = JSValue{ .number = 42.0 };
    const str = JSValue{ .string = "test" };

    try std.testing.expect(undef == .undefined);
    try std.testing.expect(null_val == .null);
    try std.testing.expectEqual(@as(f64, 42.0), num.number);
    try std.testing.expectEqualStrings("test", str.string);
}

test "Promise - lifecycle" {
    var promise = Promise(void).pending();
    try std.testing.expect(promise.isPending());
    try std.testing.expect(!promise.isFulfilled());
    try std.testing.expect(!promise.isRejected());

    promise.fulfill({});
    try std.testing.expect(!promise.isPending());
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expect(!promise.isRejected());
}

test "Promise - rejection" {
    const allocator = std.testing.allocator;

    var promise = Promise(void).pending();
    try std.testing.expect(promise.isPending());

    var exception = webidl.errors.Exception{
        .simple = .{
            .type = .TypeError,
            .message = try allocator.dupe(u8, "test error"),
        },
    };
    defer exception.deinit(allocator);

    promise.reject(exception);
    try std.testing.expect(!promise.isPending());
    try std.testing.expect(!promise.isFulfilled());
    try std.testing.expect(promise.isRejected());
    try std.testing.expectEqual(webidl.errors.SimpleException.TypeError, promise.error_value.?.simple.type);
}

test "Promise - with value type" {
    var promise = Promise(f64).pending();
    try std.testing.expect(promise.isPending());
    try std.testing.expectEqual(@as(?f64, null), promise.value);

    promise.fulfill(42.0);
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expectEqual(@as(?f64, 42.0), promise.value);
}

test "Default algorithms" {
    const cancel_algorithm = defaultCancelAlgorithm();
    const cancel_promise = cancel_algorithm.call(null);
    try std.testing.expect(cancel_promise.isFulfilled());

    const pull_algorithm = defaultPullAlgorithm();
    const pull_promise = pull_algorithm.call();
    try std.testing.expect(pull_promise.isFulfilled());

    const size_algorithm = defaultSizeAlgorithm();
    const size = size_algorithm.call(.{ .number = 100.0 });
    try std.testing.expectEqual(@as(f64, 1.0), size);

    const write_algorithm = defaultWriteAlgorithm();
    const write_promise = write_algorithm.call(.{ .string = "data" });
    try std.testing.expect(write_promise.isFulfilled());

    const close_algorithm = defaultCloseAlgorithm();
    const close_promise = close_algorithm.call();
    try std.testing.expect(close_promise.isFulfilled());

    const abort_algorithm = defaultAbortAlgorithm();
    const abort_promise = abort_algorithm.call(null);
    try std.testing.expect(abort_promise.isFulfilled());
}

test "PullAlgorithm - custom context" {
    const Context = struct {
        pull_count: usize = 0,

        pub fn pull(self: *@This()) Promise(void) {
            self.pull_count += 1;
            return Promise(void).fulfilled({});
        }
    };

    var ctx = Context{};
    const algorithm = PullAlgorithm{
        .ptr = &ctx,
        .vtable = &.{
            .call = struct {
                fn call(ptr: *anyopaque) Promise(void) {
                    const self: *Context = @ptrCast(@alignCast(ptr));
                    return self.pull();
                }
            }.call,
            .deinit = null,
        },
    };

    try std.testing.expectEqual(@as(usize, 0), ctx.pull_count);
    _ = algorithm.call();
    try std.testing.expectEqual(@as(usize, 1), ctx.pull_count);
    _ = algorithm.call();
    try std.testing.expectEqual(@as(usize, 2), ctx.pull_count);
}

test "CancelAlgorithm - custom context" {
    const Context = struct {
        canceled: bool = false,
        reason: ?JSValue = null,

        pub fn cancel(self: *@This(), r: ?JSValue) Promise(void) {
            self.canceled = true;
            self.reason = r;
            return Promise(void).fulfilled({});
        }
    };

    var ctx = Context{};
    const algorithm = CancelAlgorithm{
        .ptr = &ctx,
        .vtable = &.{
            .call = struct {
                fn call(ptr: *anyopaque, reason: ?JSValue) Promise(void) {
                    const self: *Context = @ptrCast(@alignCast(ptr));
                    return self.cancel(reason);
                }
            }.call,
            .deinit = null,
        },
    };

    try std.testing.expect(!ctx.canceled);
    _ = algorithm.call(.{ .string = "test reason" });
    try std.testing.expect(ctx.canceled);
    try std.testing.expectEqualStrings("test reason", ctx.reason.?.string);
}

test "SizeAlgorithm - custom context" {
    const Context = struct {
        multiplier: f64,

        pub fn size(self: *const @This(), chunk: JSValue) f64 {
            return switch (chunk) {
                .number => |n| n * self.multiplier,
                else => 1.0,
            };
        }
    };

    const ctx = Context{ .multiplier = 2.5 };
    const algorithm = SizeAlgorithm{
        .ptr = @constCast(&ctx),
        .vtable = &.{
            .call = struct {
                fn call(ptr: *anyopaque, chunk: JSValue) f64 {
                    const self: *const Context = @ptrCast(@alignCast(ptr));
                    return self.size(chunk);
                }
            }.call,
            .deinit = null,
        },
    };

    const size1 = algorithm.call(.{ .number = 10.0 });
    try std.testing.expectEqual(@as(f64, 25.0), size1);

    const size2 = algorithm.call(.{ .string = "test" });
    try std.testing.expectEqual(@as(f64, 1.0), size2);
}

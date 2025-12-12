//! Read request record for pending read operations
//!
//! Used by ReadableStreamDefaultReader.read() to track pending reads.
//!
//! Spec: § 4.4.4 "Read request"
//! https://streams.spec.whatwg.org/#read-request
//!
//! ## Type Safety Architecture
//!
//! This module provides both compile-time type-safe and runtime polymorphic versions
//! of the ReadRequest record:
//!
//! - `TypedReadRequest(Context)` - Generic struct with compile-time known context type
//! - `ReadRequest` - Type-erased struct for runtime polymorphism (storage in lists)
//!
//! Use `TypedReadRequest` when the context type is known at compile time.
//! Use `ReadRequest` (type-erased) when storing multiple requests with different
//! context types in the same data structure.

const std = @import("std");
const common = @import("common");

/// Value type used in read requests
/// Uses common.JSValue for type-safe JavaScript value representation
pub const Value = common.JSValue;

// ============================================================================
// Type-Safe Generic ReadRequest
// ============================================================================

/// Typed read request with compile-time known context type
///
/// A read request is a struct with three items:
/// - chunk steps: algorithm accepting a chunk
/// - close steps: algorithm accepting no parameters
/// - error steps: algorithm accepting a JavaScript value
///
/// Use this when you know the context type at compile time.
///
/// Example:
/// ```zig
/// const MyContext = struct {
///     promise: *AsyncPromise(ReadResult),
///     allocator: std.mem.Allocator,
/// };
///
/// fn onChunk(ctx: *MyContext, chunk: Value) void {
///     ctx.promise.fulfill(.{ .value = chunk, .done = false });
/// }
///
/// fn onClose(ctx: *MyContext) void {
///     ctx.promise.fulfill(.{ .value = null, .done = true });
/// }
///
/// fn onError(ctx: *MyContext, e: Value) void {
///     ctx.promise.reject(e);
/// }
///
/// var my_ctx = MyContext{ .promise = promise, .allocator = allocator };
/// const request = TypedReadRequest(MyContext).init(
///     allocator, &my_ctx, onChunk, onClose, onError,
/// );
/// ```
pub fn TypedReadRequest(comptime Context: type) type {
    return struct {
        allocator: std.mem.Allocator,
        context: *Context,

        /// chunk steps: Called when a chunk is available (typed)
        chunk_steps: *const fn (*Context, Value) void,
        /// close steps: Called when the stream closes (typed)
        close_steps: *const fn (*Context) void,
        /// error steps: Called when the stream errors (typed)
        error_steps: *const fn (*Context, Value) void,

        const Self = @This();

        /// Initialize a typed read request
        pub fn init(
            allocator: std.mem.Allocator,
            context: *Context,
            chunk_steps: *const fn (*Context, Value) void,
            close_steps: *const fn (*Context) void,
            error_steps: *const fn (*Context, Value) void,
        ) Self {
            return .{
                .allocator = allocator,
                .context = context,
                .chunk_steps = chunk_steps,
                .close_steps = close_steps,
                .error_steps = error_steps,
            };
        }

        /// Execute chunk steps with type-safe context
        pub fn executeChunkSteps(self: *const Self, chunk: Value) void {
            self.chunk_steps(self.context, chunk);
        }

        /// Execute close steps with type-safe context
        pub fn executeCloseSteps(self: *const Self) void {
            self.close_steps(self.context);
        }

        /// Execute error steps with type-safe context
        pub fn executeErrorSteps(self: *const Self, e: Value) void {
            self.error_steps(self.context, e);
        }

        /// Convert to type-erased ReadRequest for polymorphic storage
        ///
        /// Use this when you need to store requests with different context types
        /// in the same data structure (e.g., a queue of pending reads).
        pub fn erase(self: Self) ReadRequest {
            return ReadRequest{
                .allocator = self.allocator,
                .context = self.context,
                .vtable = &VTable{
                    .chunk_steps = @ptrCast(self.chunk_steps),
                    .close_steps = @ptrCast(self.close_steps),
                    .error_steps = @ptrCast(self.error_steps),
                },
            };
        }

        /// VTable for type erasure
        const VTable = ReadRequest.VTable;
    };
}

// ============================================================================
// Type-Erased ReadRequest (for runtime polymorphism)
// ============================================================================

/// Type-erased read request for runtime polymorphism
///
/// KEEP: anyopaque required - A read request is a struct with three items:
/// - chunk steps: algorithm accepting a chunk
/// - close steps: algorithm accepting no parameters
/// - error steps: algorithm accepting a JavaScript value
///
/// This type-erased version allows storing requests with different context types
/// in the same data structure. The context type information is erased at runtime.
///
/// For compile-time type safety, use `TypedReadRequest(Context)` instead.
pub const ReadRequest = struct {
    allocator: std.mem.Allocator,

    /// KEEP: anyopaque required - Type-erased context pointer for VTable pattern
    context: *anyopaque,

    /// KEEP: anyopaque required - VTable with type-erased callback function pointers
    vtable: *const VTable,

    /// KEEP: anyopaque required - VTable struct for callback dispatch
    pub const VTable = struct {
        chunk_steps: *const fn (*anyopaque, Value) void,
        close_steps: *const fn (*anyopaque) void,
        error_steps: *const fn (*anyopaque, Value) void,
    };

    /// Legacy callback function types for backward compatibility
    /// DEPRECATED: Use TypedReadRequest for new code
    pub const ChunkStepsFn = *const fn (ctx: ?*anyopaque, chunk: Value) void;
    pub const CloseStepsFn = *const fn (ctx: ?*anyopaque) void;
    pub const ErrorStepsFn = *const fn (ctx: ?*anyopaque, e: Value) void;

    /// Initialize a type-erased read request directly
    ///
    /// Prefer using `TypedReadRequest(Context).erase()` for better type safety.
    pub fn init(
        allocator: std.mem.Allocator,
        context: *anyopaque,
        vtable: *const VTable,
    ) ReadRequest {
        return .{
            .allocator = allocator,
            .context = context,
            .vtable = vtable,
        };
    }

    /// Legacy init for backward compatibility
    ///
    /// DEPRECATED: Use TypedReadRequest for new code.
    /// This provides compatibility with existing code that uses ?*anyopaque context.
    pub fn initLegacy(
        allocator: std.mem.Allocator,
        chunk_steps: ChunkStepsFn,
        close_steps: CloseStepsFn,
        error_steps: ErrorStepsFn,
        context: ?*anyopaque,
    ) ReadRequest {
        // Wrap legacy callbacks in VTable format
        const vtable = &VTable{
            .chunk_steps = @ptrCast(chunk_steps),
            .close_steps = @ptrCast(close_steps),
            .error_steps = @ptrCast(error_steps),
        };

        return .{
            .allocator = allocator,
            .context = context orelse undefined_ptr,
            .vtable = vtable,
        };
    }

    /// Execute chunk steps
    pub fn executeChunkSteps(self: *const ReadRequest, chunk: Value) void {
        self.vtable.chunk_steps(self.context, chunk);
    }

    /// Execute close steps
    pub fn executeCloseSteps(self: *const ReadRequest) void {
        self.vtable.close_steps(self.context);
    }

    /// Execute error steps
    pub fn executeErrorSteps(self: *const ReadRequest, e: Value) void {
        self.vtable.error_steps(self.context, e);
    }
};

/// Sentinel pointer for null context in legacy init.
/// Uses a static variable instead of @ptrFromInt to avoid undefined behavior.
/// The address of this variable serves as a unique sentinel value.
var sentinel_storage: u8 align(8) = 0;
const undefined_ptr: *anyopaque = @ptrCast(&sentinel_storage);

// ============================================================================
// Tests
// ============================================================================

test "TypedReadRequest - basic operations" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        chunk_received: ?Value = null,
        closed: bool = false,
        error_received: ?Value = null,

        fn onChunk(self: *@This(), chunk: Value) void {
            self.chunk_received = chunk;
        }

        fn onClose(self: *@This()) void {
            self.closed = true;
        }

        fn onError(self: *@This(), e: Value) void {
            self.error_received = e;
        }
    };

    var ctx = TestContext{};
    const request = TypedReadRequest(TestContext).init(
        allocator,
        &ctx,
        TestContext.onChunk,
        TestContext.onClose,
        TestContext.onError,
    );

    // Test chunk steps
    const chunk = Value.fromNumber(42.0);
    request.executeChunkSteps(chunk);
    try std.testing.expect(ctx.chunk_received != null);

    // Test close steps
    request.executeCloseSteps();
    try std.testing.expect(ctx.closed);

    // Test error steps
    const err = Value.createTypeError("test error");
    request.executeErrorSteps(err);
    try std.testing.expect(ctx.error_received != null);
}

test "TypedReadRequest - erase to ReadRequest" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        value: i32 = 0,

        fn onChunk(self: *@This(), _: Value) void {
            self.value += 1;
        }

        fn onClose(self: *@This()) void {
            self.value += 10;
        }

        fn onError(self: *@This(), _: Value) void {
            self.value += 100;
        }
    };

    var ctx = TestContext{};
    const typed_request = TypedReadRequest(TestContext).init(
        allocator,
        &ctx,
        TestContext.onChunk,
        TestContext.onClose,
        TestContext.onError,
    );

    // Erase to type-erased version
    const erased = typed_request.erase();

    // Operations should still work through erased interface
    erased.executeChunkSteps(Value.undefined_value());
    try std.testing.expectEqual(@as(i32, 1), ctx.value);

    erased.executeCloseSteps();
    try std.testing.expectEqual(@as(i32, 11), ctx.value);

    erased.executeErrorSteps(Value.undefined_value());
    try std.testing.expectEqual(@as(i32, 111), ctx.value);
}

test "ReadRequest - direct construction" {
    const allocator = std.testing.allocator;

    var counter: i32 = 0;
    const counter_ptr: *i32 = &counter;

    const vtable = ReadRequest.VTable{
        .chunk_steps = struct {
            fn call(ctx: *anyopaque, _: Value) void {
                const ptr: *i32 = @ptrCast(@alignCast(ctx));
                ptr.* += 1;
            }
        }.call,
        .close_steps = struct {
            fn call(ctx: *anyopaque) void {
                const ptr: *i32 = @ptrCast(@alignCast(ctx));
                ptr.* += 10;
            }
        }.call,
        .error_steps = struct {
            fn call(ctx: *anyopaque, _: Value) void {
                const ptr: *i32 = @ptrCast(@alignCast(ctx));
                ptr.* += 100;
            }
        }.call,
    };

    const request = ReadRequest.init(allocator, counter_ptr, &vtable);

    request.executeChunkSteps(Value.undefined_value());
    try std.testing.expectEqual(@as(i32, 1), counter);

    request.executeCloseSteps();
    try std.testing.expectEqual(@as(i32, 11), counter);

    request.executeErrorSteps(Value.undefined_value());
    try std.testing.expectEqual(@as(i32, 111), counter);
}

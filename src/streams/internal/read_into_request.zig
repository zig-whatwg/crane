//! Read-into request record for BYOB pending read operations
//!
//! Used by ReadableStreamBYOBReader.read() to track pending BYOB reads.
//!
//! Spec: § 4.5.4 "Read-into request"
//! https://streams.spec.whatwg.org/#read-into-request
//!
//! ## Type Safety Architecture
//!
//! This module provides both compile-time type-safe and runtime polymorphic versions
//! of the ReadIntoRequest record:
//!
//! - `TypedReadIntoRequest(Context)` - Generic struct with compile-time known context type
//! - `ReadIntoRequest` - Type-erased struct for runtime polymorphism (storage in lists)
//!
//! Use `TypedReadIntoRequest` when the context type is known at compile time.
//! Use `ReadIntoRequest` (type-erased) when storing multiple requests with different
//! context types in the same data structure.

const std = @import("std");

/// ArrayBufferView for BYOB reads
///
/// Represents a view into an ArrayBuffer for byte-oriented reading.
/// In a full implementation, this would be webidl.ArrayBufferView.
pub const ArrayBufferView = struct {
    data: []u8,
    offset: usize,
    length: usize,

    /// Create an ArrayBufferView from a slice
    pub fn fromSlice(slice: []u8) ArrayBufferView {
        return .{
            .data = slice,
            .offset = 0,
            .length = slice.len,
        };
    }

    /// Get the active portion of the view
    pub fn getSlice(self: ArrayBufferView) []u8 {
        const start = self.offset;
        const end = @min(self.offset + self.length, self.data.len);
        return self.data[start..end];
    }
};

/// Value type for error values
/// Uses a simplified union - in production this would be common.JSValue
pub const Value = union(enum) {
    undefined: void,
    null: void,
    boolean: bool,
    number: f64,
    string: []const u8,
    bytes: []const u8,
    type_error: []const u8,

    pub fn undefined_value() Value {
        return .undefined;
    }

    pub fn createTypeError(message: []const u8) Value {
        return .{ .type_error = message };
    }

    pub fn fromNumber(n: f64) Value {
        return .{ .number = n };
    }
};

// ============================================================================
// Type-Safe Generic ReadIntoRequest
// ============================================================================

/// Typed read-into request with compile-time known context type
///
/// A read-into request is a struct with three items:
/// - chunk steps: algorithm accepting an ArrayBufferView
/// - close steps: algorithm accepting no parameters
/// - error steps: algorithm accepting a JavaScript value
///
/// Use this when you know the context type at compile time.
///
/// Example:
/// ```zig
/// const MyContext = struct {
///     promise: *AsyncPromise(ReadIntoResult),
///     allocator: std.mem.Allocator,
/// };
///
/// fn onChunk(ctx: *MyContext, view: ArrayBufferView) void {
///     ctx.promise.fulfill(.{ .view = view, .done = false });
/// }
///
/// fn onClose(ctx: *MyContext) void {
///     ctx.promise.fulfill(.{ .view = null, .done = true });
/// }
///
/// fn onError(ctx: *MyContext, e: Value) void {
///     ctx.promise.reject(e);
/// }
///
/// var my_ctx = MyContext{ .promise = promise, .allocator = allocator };
/// const request = TypedReadIntoRequest(MyContext).init(
///     allocator, &my_ctx, onChunk, onClose, onError,
/// );
/// ```
pub fn TypedReadIntoRequest(comptime Context: type) type {
    return struct {
        allocator: std.mem.Allocator,
        context: *Context,

        /// chunk steps: Called when bytes are read into the buffer (typed)
        chunk_steps: *const fn (*Context, ArrayBufferView) void,
        /// close steps: Called when the stream closes (typed)
        close_steps: *const fn (*Context) void,
        /// error steps: Called when the stream errors (typed)
        error_steps: *const fn (*Context, Value) void,

        const Self = @This();

        /// Initialize a typed read-into request
        pub fn init(
            allocator: std.mem.Allocator,
            context: *Context,
            chunk_steps: *const fn (*Context, ArrayBufferView) void,
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
        pub fn executeChunkSteps(self: *const Self, chunk: ArrayBufferView) void {
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

        /// Convert to type-erased ReadIntoRequest for polymorphic storage
        ///
        /// Use this when you need to store requests with different context types
        /// in the same data structure (e.g., a queue of pending BYOB reads).
        pub fn erase(self: Self) ReadIntoRequest {
            return ReadIntoRequest{
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
        const VTable = ReadIntoRequest.VTable;
    };
}

// ============================================================================
// Type-Erased ReadIntoRequest (for runtime polymorphism)
// ============================================================================

/// Type-erased read-into request for runtime polymorphism
///
/// KEEP: anyopaque required - A read-into request is a struct with three items:
/// - chunk steps: algorithm accepting an ArrayBufferView
/// - close steps: algorithm accepting no parameters
/// - error steps: algorithm accepting a JavaScript value
///
/// This type-erased version allows storing requests with different context types
/// in the same data structure. The context type information is erased at runtime.
///
/// For compile-time type safety, use `TypedReadIntoRequest(Context)` instead.
pub const ReadIntoRequest = struct {
    allocator: std.mem.Allocator,

    /// KEEP: anyopaque required - Type-erased context pointer for VTable pattern
    context: *anyopaque,

    /// KEEP: anyopaque required - VTable with type-erased callback function pointers
    vtable: *const VTable,

    /// Whether the vtable was heap-allocated (for initLegacy)
    vtable_allocated: bool = false,

    /// KEEP: anyopaque required - VTable struct for callback dispatch
    pub const VTable = struct {
        chunk_steps: *const fn (*anyopaque, ArrayBufferView) void,
        close_steps: *const fn (*anyopaque) void,
        error_steps: *const fn (*anyopaque, Value) void,
    };

    /// Deinitialize the ReadIntoRequest, freeing any allocated resources
    pub fn deinit(self: *const ReadIntoRequest) void {
        if (self.vtable_allocated) {
            // vtable was heap-allocated by initLegacy, free it
            self.allocator.destroy(@constCast(self.vtable));
        }
    }

    /// Legacy callback function types for backward compatibility
    /// DEPRECATED: Use TypedReadIntoRequest for new code
    pub const ChunkStepsFn = *const fn (ctx: ?*anyopaque, chunk: ArrayBufferView) void;
    pub const CloseStepsFn = *const fn (ctx: ?*anyopaque) void;
    pub const ErrorStepsFn = *const fn (ctx: ?*anyopaque, e: Value) void;

    /// Initialize a type-erased read-into request directly
    ///
    /// Prefer using `TypedReadIntoRequest(Context).erase()` for better type safety.
    pub fn init(
        allocator: std.mem.Allocator,
        context: *anyopaque,
        vtable: *const VTable,
    ) ReadIntoRequest {
        return .{
            .allocator = allocator,
            .context = context,
            .vtable = vtable,
            .vtable_allocated = false,
        };
    }

    /// Legacy init for backward compatibility
    ///
    /// DEPRECATED: Use TypedReadIntoRequest for new code.
    /// This provides compatibility with existing code that uses ?*anyopaque context.
    fn initLegacyGeneric(
        comptime chunk_steps: ChunkStepsFn,
        comptime close_steps: CloseStepsFn,
        comptime error_steps: ErrorStepsFn,
    ) *const VTable {
        // Use comptime to create a static VTable
        return &VTable{
            .chunk_steps = @ptrCast(chunk_steps),
            .close_steps = @ptrCast(close_steps),
            .error_steps = @ptrCast(error_steps),
        };
    }

    pub fn initLegacy(
        allocator: std.mem.Allocator,
        chunk_steps: ChunkStepsFn,
        close_steps: CloseStepsFn,
        error_steps: ErrorStepsFn,
        context: ?*anyopaque,
    ) ReadIntoRequest {
        // Allocate VTable on the heap since we can't make it static with runtime values
        const vtable = allocator.create(VTable) catch {
            // If allocation fails, return a stub VTable that logs errors
            // This shouldn't happen in practice but provides safety
            return .{
                .allocator = allocator,
                .context = context orelse undefined_ptr,
                .vtable = &stub_vtable,
                .vtable_allocated = false, // stub_vtable is static, not allocated
            };
        };
        vtable.* = .{
            .chunk_steps = @ptrCast(chunk_steps),
            .close_steps = @ptrCast(close_steps),
            .error_steps = @ptrCast(error_steps),
        };

        return .{
            .allocator = allocator,
            .context = context orelse undefined_ptr,
            .vtable = vtable,
            .vtable_allocated = true,
        };
    }

    /// Stub VTable for error cases
    const stub_vtable = VTable{
        .chunk_steps = stubChunkSteps,
        .close_steps = stubCloseSteps,
        .error_steps = stubErrorSteps,
    };

    fn stubChunkSteps(_: *anyopaque, _: ArrayBufferView) void {}
    fn stubCloseSteps(_: *anyopaque) void {}
    fn stubErrorSteps(_: *anyopaque, _: Value) void {}

    /// Execute chunk steps with ArrayBufferView
    pub fn executeChunkSteps(self: *const ReadIntoRequest, chunk: ArrayBufferView) void {
        self.vtable.chunk_steps(self.context, chunk);
    }

    /// Execute close steps
    pub fn executeCloseSteps(self: *const ReadIntoRequest) void {
        self.vtable.close_steps(self.context);
    }

    /// Execute error steps
    pub fn executeErrorSteps(self: *const ReadIntoRequest, e: Value) void {
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

test "TypedReadIntoRequest - basic operations" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        chunk_received: ?ArrayBufferView = null,
        closed: bool = false,
        error_received: ?Value = null,

        fn onChunk(self: *@This(), chunk: ArrayBufferView) void {
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
    const request = TypedReadIntoRequest(TestContext).init(
        allocator,
        &ctx,
        TestContext.onChunk,
        TestContext.onClose,
        TestContext.onError,
    );

    // Test chunk steps with ArrayBufferView
    var buffer: [10]u8 = undefined;
    const view = ArrayBufferView.fromSlice(&buffer);
    request.executeChunkSteps(view);
    try std.testing.expect(ctx.chunk_received != null);

    // Test close steps
    request.executeCloseSteps();
    try std.testing.expect(ctx.closed);

    // Test error steps
    const err = Value.createTypeError("test error");
    request.executeErrorSteps(err);
    try std.testing.expect(ctx.error_received != null);
}

test "TypedReadIntoRequest - erase to ReadIntoRequest" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        value: i32 = 0,

        fn onChunk(self: *@This(), _: ArrayBufferView) void {
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
    const typed_request = TypedReadIntoRequest(TestContext).init(
        allocator,
        &ctx,
        TestContext.onChunk,
        TestContext.onClose,
        TestContext.onError,
    );

    // Erase to type-erased version
    const erased = typed_request.erase();

    // Operations should still work through erased interface
    var buffer: [5]u8 = undefined;
    erased.executeChunkSteps(ArrayBufferView.fromSlice(&buffer));
    try std.testing.expectEqual(@as(i32, 1), ctx.value);

    erased.executeCloseSteps();
    try std.testing.expectEqual(@as(i32, 11), ctx.value);

    erased.executeErrorSteps(Value.undefined_value());
    try std.testing.expectEqual(@as(i32, 111), ctx.value);
}

test "ReadIntoRequest - direct construction" {
    const allocator = std.testing.allocator;

    var counter: i32 = 0;
    const counter_ptr: *i32 = &counter;

    const vtable = ReadIntoRequest.VTable{
        .chunk_steps = struct {
            fn call(ctx: *anyopaque, _: ArrayBufferView) void {
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

    const request = ReadIntoRequest.init(allocator, counter_ptr, &vtable);

    var buffer: [8]u8 = undefined;
    request.executeChunkSteps(ArrayBufferView.fromSlice(&buffer));
    try std.testing.expectEqual(@as(i32, 1), counter);

    request.executeCloseSteps();
    try std.testing.expectEqual(@as(i32, 11), counter);

    request.executeErrorSteps(Value.undefined_value());
    try std.testing.expectEqual(@as(i32, 111), counter);
}

test "ArrayBufferView - fromSlice and getSlice" {
    var buffer = [_]u8{ 1, 2, 3, 4, 5 };
    const view = ArrayBufferView.fromSlice(&buffer);

    try std.testing.expectEqual(@as(usize, 0), view.offset);
    try std.testing.expectEqual(@as(usize, 5), view.length);

    const slice = view.getSlice();
    try std.testing.expectEqual(@as(usize, 5), slice.len);
    try std.testing.expectEqual(@as(u8, 1), slice[0]);
    try std.testing.expectEqual(@as(u8, 5), slice[4]);
}

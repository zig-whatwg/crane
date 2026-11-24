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
                // The steps themselves, not a pointer to a struct literal:
                // that literal of runtime values lives in this call's frame,
                // and is gone when erase() returns (lane linux1: a null
                // chunk step on x86-64 Linux).
                .vtable = .{
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

    /// KEEP: anyopaque required - VTable with type-erased callback function pointers.
    /// Held by value: the request is all its steps (a pointer would have to
    /// outlive every copy of the request).
    vtable: VTable,

    /// KEEP: anyopaque required - VTable struct for callback dispatch
    pub const VTable = struct {
        chunk_steps: *const fn (*anyopaque, ArrayBufferView) void,
        close_steps: *const fn (*anyopaque) void,
        error_steps: *const fn (*anyopaque, Value) void,
    };

    /// Deinitialize the ReadIntoRequest: it owns nothing (its steps are
    /// function pointers and its context the caller's).
    pub fn deinit(self: *const ReadIntoRequest) void {
        _ = self;
    }

    /// Initialize a type-erased read-into request directly
    ///
    /// Prefer using `TypedReadIntoRequest(Context).erase()` for better type safety.
    pub fn init(
        allocator: std.mem.Allocator,
        context: *anyopaque,
        vtable: VTable,
    ) ReadIntoRequest {
        return .{
            .allocator = allocator,
            .context = context,
            .vtable = vtable,
        };
    }

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

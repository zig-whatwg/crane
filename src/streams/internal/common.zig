//! Common types and utilities shared across the Streams implementation
//!
//! This module provides placeholder types that will eventually be replaced
//! by actual webidl types when full integration is complete.

const std = @import("std");
const webidl = @import("webidl");
const Allocator = std.mem.Allocator;

/// Error type tag for proper exception type preservation
/// Used by JSValue.error_value to indicate the type of error for V8 conversion
pub const ErrorType = enum {
    generic,
    type_error,
    range_error,
    syntax_error,
};

/// Error value structure for proper V8 exception creation
pub const ErrorValue = struct {
    error_type: ErrorType,
    message: []const u8,
};

/// Import runtime for type-safe JSValue
const runtime = @import("runtime");

/// ManagedHandle - Reference-counted wrapper for JS engine values.
///
/// This provides automatic lifecycle management for JavaScript engine handles
/// stored in stream algorithms. When the reference count reaches zero, the
/// underlying engine handle is properly disposed.
///
/// Design: This is an engine-agnostic wrapper. The actual implementation
/// uses V8Handle internally but presents a simple interface to streams code.
pub const ManagedHandle = struct {
    /// Internal state with reference counting
    inner: *Inner,

    const Inner = struct {
        /// Atomic reference count for thread safety
        ref_count: std.atomic.Value(u32),
        /// The underlying engine handle (V8 Global, JSC JSValueRef, etc.)
        /// This is owned by the ManagedHandle and disposed when ref_count hits 0
        ptr: *anyopaque,
        /// Allocator used to create this Inner (for cleanup)
        allocator: Allocator,
        /// Disposal function - called when ref_count reaches 0
        /// Set to null if the handle doesn't need disposal (e.g., non-owning reference)
        dispose_fn: ?*const fn (*anyopaque) void,
        /// Whether already disposed
        disposed: bool,

        pub fn ref(self: *Inner) void {
            _ = self.ref_count.fetchAdd(1, .monotonic);
        }

        pub fn unref(self: *Inner) void {
            if (self.ref_count.fetchSub(1, .release) == 1) {
                std.atomic.fence(.acquire);
                self.dispose();
                self.allocator.destroy(self);
            }
        }

        fn dispose(self: *Inner) void {
            if (!self.disposed) {
                if (self.dispose_fn) |dispose_fn| {
                    dispose_fn(self.ptr);
                }
                self.disposed = true;
            }
        }
    };

    /// Create a ManagedHandle that owns and will dispose the given pointer.
    pub fn init(allocator: Allocator, ptr: *anyopaque, dispose_fn: *const fn (*anyopaque) void) !ManagedHandle {
        const inner = try allocator.create(Inner);
        inner.* = .{
            .ref_count = std.atomic.Value(u32).init(1),
            .ptr = ptr,
            .allocator = allocator,
            .dispose_fn = dispose_fn,
            .disposed = false,
        };
        return .{ .inner = inner };
    }

    /// Create a non-owning ManagedHandle (won't dispose the pointer).
    pub fn initNonOwning(allocator: Allocator, ptr: *anyopaque) !ManagedHandle {
        const inner = try allocator.create(Inner);
        inner.* = .{
            .ref_count = std.atomic.Value(u32).init(1),
            .ptr = ptr,
            .allocator = allocator,
            .dispose_fn = null,
            .disposed = false,
        };
        return .{ .inner = inner };
    }

    /// Clone (increment reference count).
    pub fn clone(self: ManagedHandle) ManagedHandle {
        self.inner.ref();
        return self;
    }

    /// Release this reference.
    pub fn deinit(self: ManagedHandle) void {
        self.inner.unref();
    }

    /// Get the underlying pointer.
    pub fn get(self: ManagedHandle) *anyopaque {
        return self.inner.ptr;
    }

    /// Get reference count (for debugging/testing).
    pub fn getRefCount(self: ManagedHandle) u32 {
        return self.inner.ref_count.load(.monotonic);
    }

    /// Check if this handle is still valid.
    pub fn isValid(self: ManagedHandle) bool {
        return !self.inner.disposed;
    }
};

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
    /// V8 value pointer - stores raw V8 Global<Value>* for JavaScript engine integration
    /// Used when chunks come from JavaScript and need to be passed back unchanged
    /// NOTE: This stores a Global handle (not Local) to ensure the value survives HandleScope
    ///
    /// DEPRECATED: Prefer v8_handle for proper lifecycle management with reference counting.
    /// This variant does NOT manage the V8 handle lifecycle - the caller is responsible for
    /// ensuring the handle remains valid and is properly disposed.
    v8_value: *anyopaque,
    /// Managed handle with lifecycle management - uses reference-counted ManagedHandle wrapper
    /// This variant OWNS the engine handle and will properly dispose it when deinit is called.
    ///
    /// Use this when:
    /// - Creating JSValue that will be stored long-term
    /// - Passing V8 values through multiple owners
    /// - Any case where you want automatic cleanup on last reference
    ///
    /// Note: Clone with clone() to share ownership, call deinit() when done.
    managed_handle: ManagedHandle,
    /// Close sentinel - unique value for WritableStream close signaling
    /// Spec: § 3.9.17 "The close sentinel is a unique value enqueued into [[queue]]"
    close_sentinel: void,
    /// Error value with type information for proper V8 exception creation
    /// Preserves TypeError/RangeError/etc. distinction through the conversion pipeline
    error_value: ErrorValue,

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
    /// NOTE: Non-basic types (objects, symbols, etc.) converted to undefined
    pub fn fromWebIDL(value: webidl.JSValue) JSValue {
        return switch (value) {
            .undefined => .undefined,
            .null => .null,
            .boolean => |b| .{ .boolean = b },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = s },
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
            .v8_value => .{ .undefined = {} }, // Raw V8 values need engine-specific conversion
            .managed_handle => .{ .undefined = {} }, // Managed handles need engine-specific conversion
            .close_sentinel => .{ .undefined = {} }, // Close sentinel never exposed to web
            .error_value => |e| .{ .string = e.message }, // Convert error to string for now
        };
    }

    /// Convert JSValue to webidl.errors.Exception
    /// Used when rejecting promises - converts error values to proper exceptions
    /// Preserves error type (TypeError, RangeError, etc.) through the conversion
    pub fn toException(self: JSValue, allocator: std.mem.Allocator) !webidl.errors.Exception {
        return switch (self) {
            .error_value => |e| switch (e.error_type) {
                .type_error => try webidl.errors.Exception.typeError(allocator, e.message),
                .range_error => try webidl.errors.Exception.rangeError(allocator, e.message),
                .syntax_error => try webidl.errors.Exception.syntaxError(allocator, e.message),
                .generic => try webidl.errors.Exception.fromString(allocator, e.message),
            },
            .string => |s| try webidl.errors.Exception.fromString(allocator, s),
            else => try webidl.errors.Exception.typeError(allocator, "Unknown error"),
        };
    }

    // ========================================================================
    // Error Creation Helpers
    // ========================================================================

    /// Create a TypeError JSValue with the given message
    ///
    /// Use this when stream algorithms need to error with TypeError.
    /// The error type is preserved for proper V8 TypeError creation.
    pub fn createTypeError(message: []const u8) JSValue {
        return .{ .error_value = .{ .error_type = .type_error, .message = message } };
    }

    /// Create a RangeError JSValue with the given message
    ///
    /// Use this when stream algorithms need to error with RangeError.
    /// The error type is preserved for proper V8 RangeError creation.
    pub fn createRangeError(message: []const u8) JSValue {
        return .{ .error_value = .{ .error_type = .range_error, .message = message } };
    }

    /// Create a generic error JSValue with the given message
    pub fn createError(message: []const u8) JSValue {
        return .{ .error_value = .{ .error_type = .generic, .message = message } };
    }

    /// Check if this JSValue is an error
    pub fn isError(self: JSValue) bool {
        return self == .error_value;
    }

    /// Get error type if this is an error value
    pub fn getErrorType(self: JSValue) ?ErrorType {
        return switch (self) {
            .error_value => |e| e.error_type,
            else => null,
        };
    }

    /// Get error message if this is an error value
    pub fn getErrorMessage(self: JSValue) ?[]const u8 {
        return switch (self) {
            .error_value => |e| e.message,
            else => null,
        };
    }

    // ========================================================================
    // Value Creation Helpers
    // ========================================================================

    /// Create a string JSValue
    pub fn fromString(value: []const u8) JSValue {
        return .{ .string = value };
    }

    /// Create a number JSValue
    pub fn fromNumber(value: f64) JSValue {
        return .{ .number = value };
    }

    /// Create a boolean JSValue
    pub fn fromBool(value: bool) JSValue {
        return .{ .boolean = value };
    }

    // ========================================================================
    // ManagedHandle Lifecycle Management
    // ========================================================================

    /// Create a JSValue from a ManagedHandle (takes ownership)
    ///
    /// The JSValue takes ownership of the ManagedHandle. Call clone() on the handle
    /// before passing if you need to retain your own reference.
    pub fn fromManagedHandle(handle: ManagedHandle) JSValue {
        return .{ .managed_handle = handle };
    }

    /// Clone this JSValue if it contains a reference-counted ManagedHandle.
    ///
    /// For managed_handle variants, this increments the reference count so both
    /// the original and clone share the same underlying engine handle.
    /// For other variants, this is a simple copy (no lifecycle concerns).
    ///
    /// The caller is responsible for calling deinit() on the returned clone.
    pub fn clone(self: JSValue) JSValue {
        return switch (self) {
            .managed_handle => |h| .{ .managed_handle = h.clone() },
            // All other variants are either value types or unmanaged pointers
            else => self,
        };
    }

    /// Release resources owned by this JSValue.
    ///
    /// For managed_handle variants, this decrements the reference count and
    /// disposes the engine handle when the count reaches zero.
    /// For other variants, this is a no-op.
    ///
    /// After calling deinit(), the JSValue should not be used.
    pub fn deinit(self: JSValue) void {
        switch (self) {
            .managed_handle => |h| h.deinit(),
            // v8_value is unmanaged - caller is responsible
            // All other variants don't need cleanup
            else => {},
        }
    }

    /// Check if this JSValue holds an engine value (either managed or unmanaged)
    pub fn isEngineValue(self: JSValue) bool {
        return switch (self) {
            .v8_value, .managed_handle => true,
            else => false,
        };
    }

    /// Get the raw engine pointer for FFI operations.
    ///
    /// Returns the underlying engine pointer regardless of whether it's managed (managed_handle)
    /// or unmanaged (v8_value). For managed_handle, this gets the value from the ManagedHandle.
    ///
    /// WARNING: The returned pointer's validity depends on the lifecycle management:
    /// - For v8_value: Caller is responsible for ensuring handle is valid
    /// - For managed_handle: Valid as long as the ManagedHandle hasn't been fully deinit'd
    ///
    /// Returns null for non-engine variants.
    pub fn getEnginePtr(self: JSValue) ?*anyopaque {
        return switch (self) {
            .v8_value => |ptr| ptr,
            .managed_handle => |h| h.get(),
            else => null,
        };
    }

    /// Check if this JSValue needs lifecycle management (has owned resources).
    pub fn needsCleanup(self: JSValue) bool {
        return switch (self) {
            .managed_handle => true,
            else => false,
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
    // Store the callback but return size 1 (same as default)
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
    _ = callback;
    return defaultCancelAlgorithm();
}

/// Wrap webidl.GenericCallback as an AbortAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op abort algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericAbortCallback(callback: webidl.GenericCallback) AbortAlgorithm {
    _ = callback;
    return defaultAbortAlgorithm();
}

/// Wrap webidl.GenericCallback as a PullAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op pull algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericPullCallback(callback: webidl.GenericCallback) PullAlgorithm {
    _ = callback;
    return defaultPullAlgorithm();
}

/// Wrap webidl.GenericCallback as a CloseAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op close algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericCloseCallback(callback: webidl.GenericCallback) CloseAlgorithm {
    _ = callback;
    return defaultCloseAlgorithm();
}

/// Wrap webidl.GenericCallback as a WriteAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op write algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericWriteCallback(callback: webidl.GenericCallback) WriteAlgorithm {
    _ = callback;
    return defaultWriteAlgorithm();
}

/// Wrap webidl.GenericCallback as a TransformAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/pass-through transform algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericTransformCallback(callback: webidl.GenericCallback) TransformAlgorithm {
    _ = callback;
    return defaultTransformAlgorithm();
}

/// Wrap webidl.GenericCallback as a FlushAlgorithm
///
/// NOTE: This is a temporary stub until full zig-js-runtime integration.
/// For now, it returns a default/no-op flush algorithm since we can't invoke JS callbacks yet.
pub fn wrapGenericFlushCallback(callback: webidl.GenericCallback) FlushAlgorithm {
    _ = callback;
    return defaultFlushAlgorithm();
}

// Tests

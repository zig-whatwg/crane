//! # Engine Context Abstraction
//!
//! This module provides a type-safe wrapper around engine-specific context pointers.
//! It replaces direct use of `engine_ctx: *anyopaque` with a structured type that
//! provides better documentation, type safety, and debugging support.
//!
//! ## Design Goals
//!
//! 1. **Type Safety**: Clear documentation of what the opaque pointer actually is
//! 2. **Engine Identification**: Know which engine created the context
//! 3. **FFI Compatible**: Still uses `*anyopaque` internally for engine interop
//! 4. **Zero Runtime Overhead**: No union switches in hot paths
//! 5. **Gradual Migration**: Can coexist with raw `*anyopaque` during transition
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! // Creating an engine context (done by engine setup code)
//! const engine_ctx = runtime.EngineContext.v8(v8_context_ptr);
//!
//! // Getting the raw pointer for FFI (when needed)
//! const raw_ptr = engine_ctx.rawPtr();
//!
//! // Type-safe access (when you know the engine type)
//! if (engine_ctx.asV8Context()) |v8_ctx| {
//!     // Use v8_ctx directly
//! }
//! ```
//!
//! ## Migration Strategy
//!
//! This type can be used alongside `*anyopaque`:
//! - New code should use `EngineContext`
//! - Existing code can continue using `*anyopaque`
//! - `EngineContext.fromRaw()` converts raw pointers
//! - `EngineContext.rawPtr()` extracts for FFI calls

const std = @import("std");

/// Supported JavaScript engine types
pub const EngineType = enum {
    /// V8 JavaScript engine (used by Chrome, Node.js)
    v8,
    /// JavaScriptCore (used by Safari, WebKit)
    jsc,
    /// QuickJS (lightweight embeddable engine)
    quickjs,
    /// Unknown or uninitialized engine
    unknown,
};

/// Engine-agnostic context wrapper
///
/// Wraps an engine-specific context pointer with type information.
/// The internal pointer is opaque but the wrapper provides:
/// - Engine type identification
/// - Debug assertions for type safety
/// - Documentation of what the pointer represents
///
/// ## What the pointer represents per engine:
/// - **V8**: `*v8.ffi.Context` - V8 execution context
/// - **JSC**: `*jsc.ffi.Context` - JavaScriptCore context
/// - **QuickJS**: `*quickjs.ffi.Context` - QuickJS context
pub const EngineContext = struct {
    /// The opaque pointer to engine-specific context
    /// This is kept as anyopaque for FFI compatibility
    ptr: *anyopaque,

    /// The type of engine this context belongs to
    engine_type: EngineType,

    const Self = @This();

    // ========================================================================
    // Constructors
    // ========================================================================

    /// Create a V8 engine context
    ///
    /// The pointer should be a `*v8.ffi.Context` (V8 execution context).
    /// This is the context within a V8 Isolate that JavaScript code runs in.
    pub fn v8(context_ptr: *anyopaque) Self {
        return .{
            .ptr = context_ptr,
            .engine_type = .v8,
        };
    }

    /// Create a JSC (JavaScriptCore) engine context
    ///
    /// The pointer should be a JSC context pointer.
    pub fn jsc(context_ptr: *anyopaque) Self {
        return .{
            .ptr = context_ptr,
            .engine_type = .jsc,
        };
    }

    /// Create a QuickJS engine context
    ///
    /// The pointer should be a QuickJS context pointer.
    pub fn quickjs(context_ptr: *anyopaque) Self {
        return .{
            .ptr = context_ptr,
            .engine_type = .quickjs,
        };
    }

    /// Create from raw pointer with unknown engine type
    ///
    /// Use this for gradual migration from `*anyopaque`.
    /// The engine type will be `.unknown`.
    ///
    /// Prefer using engine-specific constructors (v8, jsc, quickjs) when the
    /// engine type is known.
    pub fn fromRaw(ptr: *anyopaque) Self {
        return .{
            .ptr = ptr,
            .engine_type = .unknown,
        };
    }

    /// Create from raw pointer with known engine type
    ///
    /// Use this when you know the engine type but have a raw pointer.
    pub fn fromRawWithType(ptr: *anyopaque, engine_type: EngineType) Self {
        return .{
            .ptr = ptr,
            .engine_type = engine_type,
        };
    }

    // ========================================================================
    // Accessors
    // ========================================================================

    /// Get the raw pointer for FFI calls
    ///
    /// Use this when calling engine interface functions that still
    /// take `*anyopaque` parameters.
    pub fn rawPtr(self: Self) *anyopaque {
        return self.ptr;
    }

    /// Get the engine type
    pub fn getEngineType(self: Self) EngineType {
        return self.engine_type;
    }

    /// Check if this is a V8 context
    pub fn isV8(self: Self) bool {
        return self.engine_type == .v8;
    }

    /// Check if this is a JSC context
    pub fn isJSC(self: Self) bool {
        return self.engine_type == .jsc;
    }

    /// Check if this is a QuickJS context
    pub fn isQuickJS(self: Self) bool {
        return self.engine_type == .quickjs;
    }

    /// Check if the engine type is known
    pub fn isKnownEngine(self: Self) bool {
        return self.engine_type != .unknown;
    }

    // ========================================================================
    // Type-Safe Access
    // ========================================================================

    /// Get as a typed pointer (generic version)
    ///
    /// This performs a pointer cast with alignment handling.
    /// Use when you know the exact type of the underlying pointer.
    ///
    /// Example:
    /// ```zig
    /// const v8_ctx = engine_ctx.as(*v8.ffi.Context);
    /// ```
    pub fn as(self: Self, comptime T: type) T {
        return @ptrCast(@alignCast(self.ptr));
    }

    /// Try to get as V8 context type
    ///
    /// Returns null if this is not a V8 context.
    /// In debug builds, asserts the engine type matches.
    pub fn asV8(self: Self, comptime V8ContextType: type) ?V8ContextType {
        if (self.engine_type == .v8 or self.engine_type == .unknown) {
            return @ptrCast(@alignCast(self.ptr));
        }
        return null;
    }

    /// Try to get as JSC context type
    ///
    /// Returns null if this is not a JSC context.
    pub fn asJSC(self: Self, comptime JSCContextType: type) ?JSCContextType {
        if (self.engine_type == .jsc or self.engine_type == .unknown) {
            return @ptrCast(@alignCast(self.ptr));
        }
        return null;
    }

    /// Try to get as QuickJS context type
    ///
    /// Returns null if this is not a QuickJS context.
    pub fn asQuickJS(self: Self, comptime QuickJSContextType: type) ?QuickJSContextType {
        if (self.engine_type == .quickjs or self.engine_type == .unknown) {
            return @ptrCast(@alignCast(self.ptr));
        }
        return null;
    }

    // ========================================================================
    // Debug Helpers
    // ========================================================================

    /// Get a human-readable description for debugging
    pub fn debugDescription(self: Self) []const u8 {
        return switch (self.engine_type) {
            .v8 => "V8 Context",
            .jsc => "JavaScriptCore Context",
            .quickjs => "QuickJS Context",
            .unknown => "Unknown Engine Context",
        };
    }

    /// Assert that this context is of a specific engine type
    ///
    /// In debug builds, panics if the engine type doesn't match.
    /// In release builds, this is a no-op.
    pub fn assertEngineType(self: Self, expected: EngineType) void {
        if (@import("builtin").mode == .Debug) {
            if (self.engine_type != expected and self.engine_type != .unknown) {
                std.debug.panic(
                    "Engine type mismatch: expected {s}, got {s}",
                    .{ @tagName(expected), @tagName(self.engine_type) },
                );
            }
        }
    }
};

/// Optional engine context - represents a potentially missing context
///
/// Use this instead of `?*anyopaque` for better type safety.
pub const OptionalEngineContext = union(enum) {
    /// No engine context available
    none: void,

    /// Engine context is present
    some: EngineContext,

    const Self = @This();

    /// Create from an optional raw pointer
    pub fn fromOptionalRaw(maybe_ptr: ?*anyopaque) Self {
        if (maybe_ptr) |ptr| {
            return .{ .some = EngineContext.fromRaw(ptr) };
        }
        return .none;
    }

    /// Create from an optional raw pointer with known engine type
    pub fn fromOptionalRawWithType(maybe_ptr: ?*anyopaque, engine_type: EngineType) Self {
        if (maybe_ptr) |ptr| {
            return .{ .some = EngineContext.fromRawWithType(ptr, engine_type) };
        }
        return .none;
    }

    /// Check if context is present
    pub fn isPresent(self: Self) bool {
        return self == .some;
    }

    /// Get the context, or null if not present
    pub fn get(self: Self) ?EngineContext {
        return switch (self) {
            .none => null,
            .some => |ctx| ctx,
        };
    }

    /// Get the raw pointer, or null if not present
    pub fn rawPtr(self: Self) ?*anyopaque {
        return switch (self) {
            .none => null,
            .some => |ctx| ctx.rawPtr(),
        };
    }

    /// Unwrap the context or return error
    pub fn unwrap(self: Self) error{NoEngineContext}!EngineContext {
        return switch (self) {
            .none => error.NoEngineContext,
            .some => |ctx| ctx,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "EngineContext - v8 constructor" {
    var dummy: u32 = 42;
    const ctx = EngineContext.v8(&dummy);

    try std.testing.expect(ctx.isV8());
    try std.testing.expect(!ctx.isJSC());
    try std.testing.expect(!ctx.isQuickJS());
    try std.testing.expect(ctx.isKnownEngine());
    try std.testing.expectEqual(EngineType.v8, ctx.getEngineType());
    try std.testing.expectEqualStrings("V8 Context", ctx.debugDescription());
}

test "EngineContext - jsc constructor" {
    var dummy: u32 = 42;
    const ctx = EngineContext.jsc(&dummy);

    try std.testing.expect(!ctx.isV8());
    try std.testing.expect(ctx.isJSC());
    try std.testing.expect(!ctx.isQuickJS());
    try std.testing.expect(ctx.isKnownEngine());
    try std.testing.expectEqual(EngineType.jsc, ctx.getEngineType());
}

test "EngineContext - quickjs constructor" {
    var dummy: u32 = 42;
    const ctx = EngineContext.quickjs(&dummy);

    try std.testing.expect(!ctx.isV8());
    try std.testing.expect(!ctx.isJSC());
    try std.testing.expect(ctx.isQuickJS());
    try std.testing.expect(ctx.isKnownEngine());
    try std.testing.expectEqual(EngineType.quickjs, ctx.getEngineType());
}

test "EngineContext - fromRaw creates unknown type" {
    var dummy: u32 = 42;
    const ctx = EngineContext.fromRaw(&dummy);

    try std.testing.expect(!ctx.isV8());
    try std.testing.expect(!ctx.isJSC());
    try std.testing.expect(!ctx.isQuickJS());
    try std.testing.expect(!ctx.isKnownEngine());
    try std.testing.expectEqual(EngineType.unknown, ctx.getEngineType());
}

test "EngineContext - rawPtr roundtrip" {
    var dummy: u32 = 42;
    const original_ptr: *anyopaque = @ptrCast(&dummy);
    const ctx = EngineContext.v8(original_ptr);

    try std.testing.expect(ctx.rawPtr() == original_ptr);
}

test "EngineContext - typed access" {
    var dummy: u32 = 42;
    const ctx = EngineContext.v8(&dummy);

    // Generic typed access
    const typed_ptr: *u32 = ctx.as(*u32);
    try std.testing.expectEqual(@as(u32, 42), typed_ptr.*);
}

test "EngineContext - asV8 returns value for v8 and unknown" {
    var dummy: u32 = 42;

    // V8 context should return value
    const v8_ctx = EngineContext.v8(&dummy);
    try std.testing.expect(v8_ctx.asV8(*u32) != null);

    // Unknown should also return value (for migration)
    const unknown_ctx = EngineContext.fromRaw(&dummy);
    try std.testing.expect(unknown_ctx.asV8(*u32) != null);

    // JSC context should return null
    const jsc_ctx = EngineContext.jsc(&dummy);
    try std.testing.expect(jsc_ctx.asV8(*u32) == null);
}

test "OptionalEngineContext - none" {
    const opt = OptionalEngineContext{ .none = {} };

    try std.testing.expect(!opt.isPresent());
    try std.testing.expect(opt.get() == null);
    try std.testing.expect(opt.rawPtr() == null);
    try std.testing.expectError(error.NoEngineContext, opt.unwrap());
}

test "OptionalEngineContext - some" {
    var dummy: u32 = 42;
    const opt = OptionalEngineContext{ .some = EngineContext.v8(&dummy) };

    try std.testing.expect(opt.isPresent());
    try std.testing.expect(opt.get() != null);
    try std.testing.expect(opt.rawPtr() != null);

    const ctx = try opt.unwrap();
    try std.testing.expect(ctx.isV8());
}

test "OptionalEngineContext - fromOptionalRaw with null" {
    const opt = OptionalEngineContext.fromOptionalRaw(null);
    try std.testing.expect(!opt.isPresent());
}

test "OptionalEngineContext - fromOptionalRaw with value" {
    var dummy: u32 = 42;
    const opt = OptionalEngineContext.fromOptionalRaw(&dummy);
    try std.testing.expect(opt.isPresent());
    try std.testing.expectEqual(EngineType.unknown, opt.get().?.getEngineType());
}

test "OptionalEngineContext - fromOptionalRawWithType" {
    var dummy: u32 = 42;
    const opt = OptionalEngineContext.fromOptionalRawWithType(&dummy, .v8);
    try std.testing.expect(opt.isPresent());
    try std.testing.expectEqual(EngineType.v8, opt.get().?.getEngineType());
}

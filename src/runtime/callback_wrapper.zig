//! Engine-Agnostic Callback Wrapper
//!
//! This module provides an engine-agnostic wrapper for WebIDL callback interfaces
//! (EventListener, NodeFilter, XPathNSResolver, etc.). The actual implementation
//! is delegated to the JavaScript engine through the EngineInterface.
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! // In impl code, receive callback wrapper
//! pub fn call_addEventListener(
//!     instance: *runtime.Instance,
//!     event_type: []const u8,
//!     callback: ?*runtime.CallbackWrapper,
//!     options: anytype,
//! ) !void {
//!     if (callback) |cb| {
//!         // Store the callback
//!         try instance.storeCallback(event_type, cb);
//!     }
//! }
//!
//! // Later, invoke the callback
//! pub fn dispatchEvent(instance: *runtime.Instance, event: *Event) !void {
//!     if (instance.getCallback("click")) |cb| {
//!         const event_value = try convertToJsValue(event);
//!         _ = try cb.invoke(&.{event_value});
//!     }
//! }
//! ```

const std = @import("std");
const EngineInterface = @import("engine_interface.zig").EngineInterface;
const EngineError = @import("engine_interface.zig").EngineError;

/// Engine-agnostic callback wrapper
///
/// Wraps a JavaScript callback (function or object with callable method)
/// for use in WebIDL callback interfaces like EventListener.
///
/// This is a thin wrapper that delegates all operations to the JS engine
/// through the EngineInterface.
pub const CallbackWrapper = struct {
    /// Opaque handle to the engine-specific callback wrapper
    engine_handle: *anyopaque,

    /// The engine interface for callback operations
    engine: *const EngineInterface,

    /// Engine context needed for invocation
    engine_ctx: *anyopaque,

    /// Allocator used for this wrapper
    allocator: std.mem.Allocator,

    /// Create a callback wrapper from a JavaScript value
    ///
    /// Arguments:
    ///   - engine: The engine interface to use
    ///   - engine_ctx: Engine-specific context (V8 Context, etc.)
    ///   - js_value: Opaque pointer to the JS value (function or object)
    ///   - method_name: For object callbacks, the method to call (e.g., "handleEvent")
    ///   - allocator: Allocator for wrapper storage
    ///
    /// Returns:
    ///   - CallbackWrapper if value is callable, null otherwise
    pub fn init(
        engine: *const EngineInterface,
        engine_ctx: *anyopaque,
        js_value: *anyopaque,
        method_name: [*:0]const u8,
        allocator: std.mem.Allocator,
    ) !?CallbackWrapper {
        const create_fn = engine.createCallbackWrapper orelse
            return error.CallbackNotSupported;

        const handle = try create_fn(engine_ctx, js_value, method_name, allocator);
        if (handle) |h| {
            return CallbackWrapper{
                .engine_handle = h,
                .engine = engine,
                .engine_ctx = engine_ctx,
                .allocator = allocator,
            };
        }
        return null;
    }

    /// Invoke the callback with arguments
    ///
    /// Arguments are passed as opaque pointers to JS values.
    /// The return value is also an opaque pointer to a JS value.
    pub fn invoke(self: *const CallbackWrapper, args: []const *anyopaque) !?*anyopaque {
        const invoke_fn = self.engine.invokeCallback orelse
            return error.CallbackNotSupported;

        return try invoke_fn(
            self.engine_ctx,
            self.engine_handle,
            args.ptr,
            args.len,
        );
    }

    /// Invoke the callback with no arguments
    pub fn invoke0(self: *const CallbackWrapper) !?*anyopaque {
        return self.invoke(&.{});
    }

    /// Invoke the callback with one argument
    pub fn invoke1(self: *const CallbackWrapper, arg0: *anyopaque) !?*anyopaque {
        return self.invoke(&.{arg0});
    }

    /// Invoke the callback with two arguments
    pub fn invoke2(self: *const CallbackWrapper, arg0: *anyopaque, arg1: *anyopaque) !?*anyopaque {
        return self.invoke(&.{ arg0, arg1 });
    }

    /// Clean up the callback wrapper
    ///
    /// This releases the persistent handle to the JS function/object.
    /// After calling deinit, the wrapper should not be used.
    pub fn deinit(self: *CallbackWrapper) void {
        if (self.engine.destroyCallbackWrapper) |destroy_fn| {
            destroy_fn(self.engine_handle);
        }
    }
};

/// Error for callback operations
pub const CallbackError = error{
    /// The engine doesn't support callback wrappers
    CallbackNotSupported,
    /// Failed to create callback wrapper
    CreationFailed,
    /// Failed to invoke callback
    InvocationFailed,
} || EngineError;

// ============================================================================
// Tests
// ============================================================================

test "CallbackWrapper - struct size" {
    const testing = std.testing;

    // Should be reasonably small
    try testing.expect(@sizeOf(CallbackWrapper) <= 64);
}

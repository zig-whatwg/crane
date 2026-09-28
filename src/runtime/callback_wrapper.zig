//! A callback interface value as the binding converts it today.
//!
//! WebIDL callback interfaces (EventListener, NodeFilter, XPathNSResolver)
//! reach impls as a `*CallbackWrapper`: an adapter-made handle to the
//! function or object, which the engine protocol's takeCallbackInterface
//! reads (engine_protocol.zig names this type as TRANSITIONAL). The adapter's
//! binding makes one; an impl that stores the callback keeps it, and an impl
//! that does not `deinit`s it.
//!
//! TRANSITIONAL, with `CallbackOperations`: both go when the binding's
//! callback interface conversion (src/runtime/engines/v8/conversions.zig)
//! hands impls the protocol's CallbackInterface instead.

const std = @import("std");

/// What a CallbackWrapper needs from the adapter that made it: the one
/// operation that ends it. (It was the runtime Engine table, which is gone;
/// the adapter's binding names its value.)
pub const CallbackOperations = struct {
    /// Release the adapter's handle to the callback (`engine_handle`).
    destroyCallbackWrapper: *const fn (callback_wrapper: *anyopaque) void,
};

/// Wraps a JavaScript callback (function or object with callable method)
/// for use in WebIDL callback interfaces like EventListener.
pub const CallbackWrapper = struct {
    /// Opaque handle to the engine-specific callback wrapper
    engine_handle: *anyopaque,

    /// The adapter's operations on `engine_handle`.
    engine: *const CallbackOperations,

    /// The realm the callback was converted in (the adapter's context handle).
    engine_ctx: *anyopaque,

    /// Allocator used for this wrapper
    allocator: std.mem.Allocator,

    /// Clean up the callback wrapper
    ///
    /// This releases the persistent handle to the JS function/object.
    /// After calling deinit, the wrapper should not be used.
    pub fn deinit(self: *CallbackWrapper) void {
        self.engine.destroyCallbackWrapper(self.engine_handle);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "CallbackWrapper - struct size" {
    const testing = std.testing;

    // Should be reasonably small
    try testing.expect(@sizeOf(CallbackWrapper) <= 64);
}

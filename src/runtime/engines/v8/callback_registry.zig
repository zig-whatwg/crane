//! Callback Registry - Stub implementation
//!
//! This file tracks V8 callback wrappers for cleanup when contexts are destroyed.
//! TODO: Full implementation needed for proper callback lifecycle management.

const std = @import("std");
const callback_wrapper = @import("callback_wrapper.zig");

/// Register a callback wrapper for tracking
pub fn register(wrapper: *callback_wrapper.CallbackWrapper) void {
    // Stub: In a full implementation, this would track the wrapper
    // for cleanup when the context is destroyed
    _ = wrapper;
}

/// Clean up all registered callbacks for a context
pub fn cleanupForContext(context: anytype) void {
    _ = context;
    // Stub: Would iterate and clean up all callbacks registered to this context
}

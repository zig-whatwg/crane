//! CallbackWrapper Registry
//!
//! This module provides a thread-local registry for tracking CallbackWrapper instances.
//! CallbackWrappers are created when JavaScript functions are passed to Zig code
//! (e.g., addEventListener callbacks, Promise handlers, etc.) and need to be
//! properly cleaned up when the V8 context is destroyed.
//!
//! ## The Problem
//!
//! CallbackWrapper instances are heap-allocated and store persistent V8 Global handles.
//! Without tracking, these wrappers leak when:
//! - The V8 context is destroyed
//! - The page navigates away
//! - Tests complete without explicit cleanup
//!
//! ## Solution
//!
//! This registry tracks all CallbackWrapper instances created during V8 -> Zig
//! conversions. When the context is destroyed, all tracked wrappers are cleaned up
//! by calling their deinit() method, which:
//! 1. Disposes the V8 Global handles (allows V8 GC to collect the JS function)
//! 2. Frees the wrapper's heap memory
//!
//! ## Usage
//!
//! ```zig
//! // Initialize registry (once per thread, typically in Context.init)
//! callback_registry.init(allocator);
//!
//! // Register a wrapper (in conversions.zig when creating CallbackWrapper)
//! callback_registry.register(wrapper);
//!
//! // Clean up all wrappers (in Context.deinit)
//! callback_registry.deinit();
//! ```

const std = @import("std");
const CallbackWrapper = @import("callback_wrapper.zig").CallbackWrapper;

/// Thread-local storage for the callback registry
threadlocal var registry: ?std.AutoArrayHashMap(*CallbackWrapper, void) = null;
threadlocal var registry_allocator: ?std.mem.Allocator = null;

/// Initialize the callback registry for the current thread.
/// Call this once when creating a new browser context.
///
/// If already initialized, this is a no-op (allows multiple context creations
/// within the same thread without errors).
pub fn init(allocator: std.mem.Allocator) void {
    if (registry == null) {
        registry = std.AutoArrayHashMap(*CallbackWrapper, void).init(allocator);
        registry_allocator = allocator;
    }
}

/// Register a CallbackWrapper for tracking.
/// The wrapper will be automatically cleaned up when deinit() is called.
///
/// This should be called immediately after creating a CallbackWrapper
/// in conversions.zig.
pub fn register(wrapper: *CallbackWrapper) void {
    if (registry) |*reg| {
        reg.put(wrapper, {}) catch |err| {
            // If we can't track it, we should still continue
            // The wrapper will leak, but that's better than crashing
            std.debug.print("Warning: Failed to register CallbackWrapper: {}\n", .{err});
        };
    }
}

/// Unregister a CallbackWrapper without destroying it.
/// Use this when a wrapper is explicitly cleaned up by user code
/// (e.g., removeEventListener).
pub fn unregister(wrapper: *CallbackWrapper) void {
    if (registry) |*reg| {
        _ = reg.swapRemove(wrapper);
    }
}

/// Clean up all registered CallbackWrappers and reset the registry.
/// Call this when destroying a browser context.
///
/// This method:
/// 1. Calls deinit() on each registered wrapper (disposes V8 handles, frees memory)
/// 2. Clears and deallocates the registry
/// 3. Resets thread-local state to null
pub fn deinit() void {
    if (registry) |*reg| {
        // Iterate over all registered wrappers and clean them up
        var iter = reg.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.key_ptr.*;
            // deinit disposes V8 Global handles and frees wrapper memory
            wrapper.deinit();
        }

        // Clear the registry
        reg.deinit();
        registry = null;
        registry_allocator = null;
    }
}

/// Clear all registered wrappers without destroying the registry.
/// Use this for test isolation between test runs within the same context.
pub fn clearAll() void {
    if (registry) |*reg| {
        var iter = reg.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.key_ptr.*;
            wrapper.deinit();
        }
        reg.clearRetainingCapacity();
    }
}

/// Get the number of registered wrappers.
/// Useful for debugging and testing.
pub fn count() usize {
    if (registry) |reg| {
        return reg.count();
    }
    return 0;
}

/// Check if the registry is initialized.
pub fn isInitialized() bool {
    return registry != null;
}

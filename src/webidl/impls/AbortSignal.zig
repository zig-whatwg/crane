//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for AbortSignal interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Remove this header comment block
//!   3. Add your implementation logic
//!   4. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const AbortSignal = interfaces.AbortSignal;

pub const State = AbortSignal.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for aborted
pub fn get_aborted(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for reason
pub fn get_reason(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: _any
pub fn call__any(instance: *runtime.Instance, signals: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = signals;
    return error.NotImplemented;
}

/// Operation: abort
pub fn call_abort(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = reason;
    return error.NotImplemented;
}

/// Operation: timeout
pub fn call_timeout(instance: *runtime.Instance, milliseconds: u64) ImplError!*runtime.Instance {
    _ = instance;
    _ = milliseconds;
    return error.NotImplemented;
}

/// Operation: throwIfAborted
pub fn call_throwIfAborted(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Helper: Signal abort on this signal (called by AbortController)
pub fn signalAbort(instance: *runtime.Instance, reason: ?*const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // If already aborted, do nothing
    if (internal.aborted) {
        return;
    }

    // Set aborted to true
    internal.aborted = true;

    // Set reason
    internal.reason = reason;

    // Fire abort event (requires DOM event infrastructure)
    // For now, just set the flag - event firing would happen here
}

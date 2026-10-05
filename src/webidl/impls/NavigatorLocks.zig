//! Implementation for NavigatorLocks interface
//!
//! Web Locks 3.1: Navigator and WorkerNavigator include NavigatorLocks, so
//! both inherit this one `locks` getter.
//!
//! Spec: https://w3c.github.io/web-locks/#navigator-mixins

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorLocks = interfaces.NavigatorLocks;

pub const State = NavigatorLocks.State;

pub const ImplError = error{
    NotImplemented,
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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Web Locks 3.1: "The locks getter's steps are to return this's relevant
/// settings object's LockManager object" - LockManager's to make and find
/// (html.web_locks.lock_managers). `this` is a Navigator or a
/// WorkerNavigator; its relevant realm is its environment's.
pub fn get_locks(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return @import("html").web_locks.lock_managers.of(instance.ctx);
}

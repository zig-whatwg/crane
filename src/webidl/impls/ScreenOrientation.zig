//! Implementation for ScreenOrientation interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ScreenOrientation = interfaces.ScreenOrientation;

pub const State = ScreenOrientation.State;

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

/// Getter for type: [[type]] (Screen Orientation, "type attribute").
pub fn get_type(instance: *runtime.Instance) anyerror!enums.OrientationType {
    return switch (@import("html").screen_orientation.typeOf(instance)) {
        .portrait_primary => ._portrait_primary_,
        .portrait_secondary => ._portrait_secondary_,
        .landscape_primary => ._landscape_primary_,
        .landscape_secondary => ._landscape_secondary_,
    };
}

/// Getter for angle: [[angle]] (Screen Orientation, "angle attribute").
pub fn get_angle(instance: *runtime.Instance) anyerror!u16 {
    return @import("html").screen_orientation.angleOf(instance);
}

// onchange: the generated EventTarget event handler attribute (event type
// "change"), which html.screen_orientation's change steps fire.

/// Operation: unlock (Screen Orientation, "unlock() method";
/// html.screen_orientation.unlock).
pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
    try @import("html").screen_orientation.unlock(instance);
}

/// Operation: lock (Screen Orientation, "lock() method";
/// html.screen_orientation.lock): every orientation is one the user agent
/// does not support locking to, as Chrome desktop.
pub fn call_lock(instance: *runtime.Instance, orientation: enums.OrientationLockType) anyerror!runtime.JSValue {
    _ = orientation;
    return @import("html").screen_orientation.lock(instance);
}

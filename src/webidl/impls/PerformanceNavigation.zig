//! Implementation for PerformanceNavigation interface
//!
//! Spec: https://w3c.github.io/navigation-timing/#the-performancenavigation-interface
//!
//! Navigation Timing 1's `performance.navigation`, obsolete: answered from
//! the document's navigation timing entry (its type and redirect count).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceNavigation = interfaces.PerformanceNavigation;

pub const State = PerformanceNavigation.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for type: TYPE_NAVIGATE (0), TYPE_RELOAD (1) or TYPE_BACK_FORWARD
/// (2), from the navigation timing entry's type; TYPE_NAVIGATE for a
/// document no navigation made.
pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
    const entry = performance_timeline.navigationEntryOf(instance.ctx) orelse return 0;
    const navigation_type = try interfaces.PerformanceNavigationTiming.get_type(entry);
    return switch (navigation_type) {
        ._navigate_ => 0,
        ._reload_ => 1,
        ._back_forward_ => 2,
    };
}

/// Getter for redirectCount: the navigation timing entry's.
pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
    const entry = performance_timeline.navigationEntryOf(instance.ctx) orelse return 0;
    return interfaces.PerformanceNavigationTiming.get_redirectCount(entry);
}

/// Operation: toJSON (WebIDL default toJSON steps)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceNavigation.PerformanceNavigationToJSON {
    return .{ .type = try get_type(instance), .redirectCount = try get_redirectCount(instance) };
}

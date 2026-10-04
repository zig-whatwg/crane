//! Implementation for PerformanceMeasure interface
//!
//! Spec: https://w3c.github.io/user-timing/#performancemeasure
//!
//! PerformanceMeasure has no constructor: measure() makes one (User Timing
//! 2.1.3 steps 4-9) through `dom.performance_timeline.createMeasure`, which
//! this impl installs.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceMeasure = interfaces.PerformanceMeasure;

pub const State = PerformanceMeasure.State;

pub const ImplError = error{
    NotImplemented,
};

/// A measure's own state is its detail, which its wrapper keeps
/// (`detail_slot`); its PerformanceEntry attributes are PerformanceEntry's.
pub const InternalState = struct {};

/// The member a measure keeps its detail in (engine.traceValue).
const detail_slot: engine.TracedSlot = .{ .name = "detail" };

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installMeasures(.{ .create = &createMeasure });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the detail's waiting edge (a measure freed
/// unwrapped), then PerformanceEntry's part.
pub fn deinit(instance: *runtime.Instance) void {
    engine.forgetTracedChild(instance, detail_slot);
    interfaces.PerformanceEntry.deinit(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// User Timing 2.1.3 steps 4-9: a new PerformanceMeasure in `realm` (this's
/// relevant realm) named `measure_name`, entryType "measure", from
/// `start_time`, its duration the one from start time to `end_time`, its
/// detail `detail` (already deserialized in the current realm) or null.
fn createMeasure(realm: runtime.Context, measure_name: []const u8, start_time: f64, end_time: f64, detail: ?runtime.JSValue) anyerror!*runtime.Instance {
    const instance = try init(realm.allocator, State, &PerformanceMeasure.vtable, realm);
    errdefer runtime.Instance.deinit(instance);
    try performance_timeline.initializeEntry(instance, start_time, .measure, measure_name, end_time);
    if (detail) |value| engine.traceValue(instance, value, detail_slot);
    return instance;
}

/// Getter for detail: the value it was set to, or null.
pub fn get_detail(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const detail = engine.tracedValue(instance, detail_slot) orelse return runtime.JSValue.jsNull;
    return detail.take();
}

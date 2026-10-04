//! Implementation for PerformanceEntry interface
//!
//! Spec: https://w3c.github.io/performance-timeline/#the-performanceentry-interface
//!
//! An entry's attributes are set once, by "initialize a PerformanceEntry",
//! which every entry type runs as it is made (PerformanceMark's constructor,
//! measure(), the resource and navigation timing entries) - through
//! `dom.performance_timeline`, which this impl installs it into, since no
//! entry type may name this impl. The timeline reads the attributes the same
//! way, and completes `id` and `navigationId` when it queues the entry.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceEntry = interfaces.PerformanceEntry;

pub const State = PerformanceEntry.State;

pub const ImplError = error{
    NotImplemented,
};

/// The entry's attributes. Allocated by "initialize a PerformanceEntry"
/// (an entry type's instance carries this as its PerformanceEntry part),
/// freed by `deinit`, which every entry type's teardown chains to.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    data: performance_timeline.EntryData,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installEntries(.{ .initialize = &initializeEntry, .data = &dataOf });
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

/// Deinitialize instance: the attributes "initialize a PerformanceEntry"
/// allocated. Every entry type's deinit chains here.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.allocator.free(internal.data.name);
    internal.allocator.destroy(internal);
    state.own._internal = null;
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// "initialize a PerformanceEntry" (Performance Timeline 3) `entry` given
/// startTime, entryType, name and end time.
fn initializeEntry(entry: *runtime.Instance, start_time: f64, entry_type: performance_timeline.EntryType, entry_name: []const u8, end_time: f64) anyerror!void {
    const state = entry.getState(State);
    const allocator = entry.ctx.allocator;
    // 1. entryType is in the registry (the EntryType enum says so).
    const name_copy = try allocator.dupe(u8, entry_name);
    errdefer allocator.free(name_copy);
    if (state.own._internal) |existing| {
        allocator.free(existing.data.name);
        existing.data = .{ .name = name_copy, .entry_type = entry_type, .start_time = start_time, .end_time = end_time };
        return;
    }
    const internal = try allocator.create(InternalState);
    // 2-5. startTime, entryType, name and end time.
    internal.* = .{
        .allocator = allocator,
        .data = .{ .name = name_copy, .entry_type = entry_type, .start_time = start_time, .end_time = end_time },
    };
    state.own._internal = internal;
}

fn dataOf(entry: *runtime.Instance) ?*performance_timeline.EntryData {
    const state = entry.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.data;
}

fn data(instance: *runtime.Instance) !*performance_timeline.EntryData {
    return dataOf(instance) orelse error.InvalidStateError;
}

/// Getter for id
pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
    return (try data(instance)).id;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // The entry keeps its name; the binding copies it.
    return runtime.DOMString.initInterned((try data(instance)).name);
}

/// Getter for entryType
pub fn get_entryType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try data(instance)).entry_type.name());
}

/// Getter for startTime
pub fn get_startTime(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try data(instance)).start_time;
}

/// Getter for duration: 0 if this's end time is 0, otherwise end time -
/// startTime.
pub fn get_duration(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try data(instance)).duration();
}

/// Getter for navigationId
pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
    return (try data(instance)).navigation_id;
}

/// Operation: toJSON - WebIDL's default toJSON steps: PerformanceEntry's
/// attributes (the inheritance stack of the interface declaring toJSON;
/// an entry type's own attributes are added only where it declares a
/// [Default] toJSON of its own).
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceEntry.PerformanceEntryToJSON {
    const d = try data(instance);
    return .{
        .id = d.id,
        .name = runtime.DOMString.initInterned(d.name),
        .entryType = runtime.DOMString.initInterned(d.entry_type.name()),
        .startTime = d.start_time,
        .duration = d.duration(),
        .navigationId = d.navigation_id,
    };
}

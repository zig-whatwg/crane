//! Server Timing §3: an immutable metric of a final HTTP response.
//! https://w3c.github.io/server-timing/#the-performanceservertiming-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const Metric = @import("fetch").internal.fetch_timing.server_timing.Metric;
const PerformanceServerTiming = interfaces.PerformanceServerTiming;

pub const State = PerformanceServerTiming.State;

pub const construction_args = .{"metric"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    metric: Metric,
};

/// Server Timing §3.3: copy one parsed metric into its platform object.
/// The entry and the metric can independently outlive each other.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const metric: Metric = if (@hasField(@TypeOf(args), "metric")) args.metric else .{ .name = "" };
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    const name = try allocator.dupe(u8, metric.name);
    errdefer allocator.free(name);
    const description = try allocator.dupe(u8, metric.description);
    internal.* = .{ .allocator = allocator, .metric = .{ .name = name, .duration = metric.duration, .description = description } };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.allocator.free(internal.metric.name);
    internal.allocator.free(internal.metric.description);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn metricOf(instance: *runtime.Instance) !*const Metric {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return &(state.own._internal orelse return error.InvalidStateError).metric;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try metricOf(instance)).name);
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try metricOf(instance)).duration;
}

/// Getter for description
pub fn get_description(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try metricOf(instance)).description);
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceServerTiming.PerformanceServerTimingToJSON {
    const metric = try metricOf(instance);
    return .{
        .name = runtime.DOMString.initInterned(metric.name),
        .duration = metric.duration,
        .description = runtime.DOMString.initInterned(metric.description),
    };
}

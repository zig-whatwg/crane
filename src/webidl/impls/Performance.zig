//! Implementation for Performance interface
//!
//! Spec: https://w3c.github.io/hr-time/#the-performance-interface
//! Spec: https://w3c.github.io/performance-timeline/#extensions-to-the-performance-interface
//! Spec: https://w3c.github.io/user-timing/#extensions-performance-interface
//!
//! One Performance per global. It carries the global's time origin and its
//! performance timeline (`dom.performance_timeline.Timeline`: the entry
//! buffers, the registered observers, the observer task flag), which the
//! other timeline types reach through the hooks this impl installs.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const hr_time = @import("hr_time");
const dom = @import("dom");
const performance_timeline = dom.performance_timeline;
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const Performance = interfaces.Performance;

pub const State = Performance.State;

pub const ImplError = error{
    NotImplemented,
};

/// The global's time origin and performance timeline.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The time origin of the global's environment settings object.
    time_origin: hr_time.TimeOrigin,
    /// The global's performance timeline.
    timeline: performance_timeline.Timeline,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installPerformances(.{
        .of_realm = &timelineOfRealm,
        .of_performance = &timelineOfPerformance,
        .now = &nowOfRealm,
        .relative_coarse_time = &relativeCoarseTimeOfRealm,
    });
}

/// Initialize instance (creates the instance)
///
/// HR-Time: the time origin is the global's environment settings object's,
/// which the global records when it is made (a Window: at its creation,
/// standing in for its document's navigation start time) - never the moment
/// this object is made, which may be much later (a frame's `performance`
/// read for the first time).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
        .time_origin = timeOriginOf(ctx),
        .timeline = performance_timeline.Timeline.init(allocator, instance),
    };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// The time origin of `ctx`'s global's settings object.
fn timeOriginOf(ctx: runtime.Context) hr_time.TimeOrigin {
    const global = globalOf(ctx) orelse return hr_time.TimeOrigin.init(false);
    const settings = dom.global_settings.of(global) orelse return hr_time.TimeOrigin.init(false);
    const cross_origin_isolated = settings.cross_origin_isolated(global);
    const recorded = if (settings.time_origin) |time_origin| time_origin(global) else null;
    const moment = recorded orelse return hr_time.TimeOrigin.init(cross_origin_isolated);
    // The estimated monotonic time of the Unix epoch, as TimeOrigin.init
    // computes it; the origin is the recorded moment, coarsened.
    const now_origin = hr_time.TimeOrigin.init(cross_origin_isolated);
    return hr_time.TimeOrigin.initWithOrigin(
        hr_time.coarsenTime(@as(hr_time.Nanoseconds, moment), cross_origin_isolated),
        now_origin.estimated_epoch,
        cross_origin_isolated,
    );
}

/// `ctx`'s global object, as its realm records it.
fn globalOf(ctx: runtime.Context) ?*runtime.Instance {
    const record = ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.timeline.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // NOTE: Don't call runtime.Instance.deinit(instance) here!
    // The GC integration layer (gc.onObjectFreed) handles freeing the slab.
}

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

fn timeline(instance: *runtime.Instance) !*performance_timeline.Timeline {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return &internal.timeline;
}

// ============================================================================
// dom.performance_timeline hooks
// ============================================================================

/// The Performance of `realm`'s global object, made by the global if it has
/// not made it yet.
fn performanceOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const global = globalOf(realm) orelse return null;
    const settings = dom.global_settings.of(global) orelse return null;
    const performance = settings.performance orelse return null;
    return performance(global) catch null;
}

fn timelineOfRealm(realm: runtime.Context) ?*performance_timeline.Timeline {
    const performance = performanceOfRealm(realm) orelse return null;
    return timelineOfPerformance(performance);
}

fn timelineOfPerformance(performance: *runtime.Instance) ?*performance_timeline.Timeline {
    const state = performance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.timeline;
}

fn nowOfRealm(realm: runtime.Context) ?f64 {
    const performance = performanceOfRealm(realm) orelse return null;
    const internal = getInternal(performance) orelse return null;
    return internal.time_origin.currentRelativeTimestampMs();
}

/// HR-Time "relative high resolution coarse time" of `unsafe_ms` - a moment
/// of the unsafe shared current time (the monotonic clock), in ms - for
/// `realm`'s global: the moment coarsened, minus the time origin.
fn relativeCoarseTimeOfRealm(realm: runtime.Context, unsafe_ms: f64) ?f64 {
    const performance = performanceOfRealm(realm) orelse return null;
    const internal = getInternal(performance) orelse return null;
    const origin = internal.time_origin;
    const moment: hr_time.Nanoseconds = @intFromFloat(unsafe_ms * std.time.ns_per_ms);
    const coarse = hr_time.coarsenTime(moment, origin.cross_origin_isolated);
    return hr_time.toMilliseconds(coarse - origin.origin_moment);
}

// ============================================================================
// HR-Time
// ============================================================================

/// Getter for timeOrigin
///
/// HR-Time 3.4.2: get time origin timestamp for the relevant global object.
pub fn get_timeOrigin(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.time_origin.getTimeOriginTimestampMs();
}

/// Operation: now
///
/// HR-Time 3.4.1: the current high resolution time for the relevant global
/// object.
pub fn call_now(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.time_origin.currentRelativeTimestampMs();
}

/// Operation: toJSON
/// TODO(perftimeline): [Default] toJSON needs `timing` and `navigation`
/// (Navigation Timing's PerformanceTiming and PerformanceNavigation) and
/// `eventCounts` to exist first.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.Performance.PerformanceToJSON {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for eventCounts
pub fn get_eventCounts(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for interactionCount
pub fn get_interactionCount(instance: *runtime.Instance) anyerror!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timing
pub fn get_timing(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for navigation
pub fn get_navigation(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onresourcetimingbufferfull
pub fn get_onresourcetimingbufferfull(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onresourcetimingbufferfull
pub fn set_onresourcetimingbufferfull(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

// ============================================================================
// Performance Timeline 2.1
// ============================================================================

/// `entries` as a PerformanceEntryList: an Array of the current realm.
/// Wrapping hands each entry's wrapper to the array; the timeline keeps them
/// meanwhile.
fn entryList(instance: *runtime.Instance, list: []const *runtime.Instance) !runtime.JSValue {
    const realm = engine.currentRealm() orelse instance.ctx;
    const array = try engine.createSequenceOfPlatformObjects(realm, list);
    return array.take();
}

/// Operation: getEntries - filter buffer map by name and type, both null.
pub fn call_getEntries(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;
    const list = try performance_timeline.filterBufferMap(try timeline(instance), allocator, null, null);
    defer allocator.free(list);
    return entryList(instance, list);
}

/// Operation: getEntriesByType - filter buffer map with name null.
pub fn call_getEntriesByType(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;
    const list = try performance_timeline.filterBufferMap(try timeline(instance), allocator, null, @"type".asSlice());
    defer allocator.free(list);
    return entryList(instance, list);
}

/// Operation: getEntriesByName - filter buffer map with name, and type
/// null when it is omitted.
pub fn call_getEntriesByName(instance: *runtime.Instance, name: runtime.DOMString, @"type": webidl.Opt(runtime.DOMString)) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;
    const type_filter: ?[]const u8 = if (@"type".was_passed) @"type".value.asSlice() else null;
    const list = try performance_timeline.filterBufferMap(try timeline(instance), allocator, name.asSlice(), type_filter);
    defer allocator.free(list);
    return entryList(instance, list);
}

// ============================================================================
// User Timing 2.1
// ============================================================================

/// Operation: mark (User Timing 2.1.1)
pub fn call_mark(instance: *runtime.Instance, markName: runtime.DOMString, markOptions: webidl.Opt(dictionaries.PerformanceMarkOptions)) anyerror!*runtime.Instance {
    // 1. Run the PerformanceMark constructor: in the current global
    // object's realm.
    const realm = engine.currentRealm() orelse instance.ctx;
    const entry = try interfaces.PerformanceMark.call_constructor(realm, markName, markOptions);
    const generation = runtime.SlabAllocator.generationOf(entry);
    errdefer entry.releaseIfUnwrapped(generation);
    // 2-3. Queue it on its relevant global's timeline (which adds it to the
    // performance entry buffer).
    const entry_timeline = performance_timeline.timelineOf(entry.ctx) orelse try timeline(instance);
    try performance_timeline.queueEntry(entry_timeline, entry);
    // 4.
    return entry;
}

/// Operation: clearMarks (User Timing 2.1.2)
pub fn call_clearMarks(instance: *runtime.Instance, markName: webidl.Opt(runtime.DOMString)) anyerror!void {
    const name: ?[]const u8 = if (markName.was_passed) markName.value.asSlice() else null;
    performance_timeline.clearEntries(try timeline(instance), .mark, name);
}

/// Operation: clearMeasures (User Timing 2.1.4)
pub fn call_clearMeasures(instance: *runtime.Instance, measureName: webidl.Opt(runtime.DOMString)) anyerror!void {
    const name: ?[]const u8 = if (measureName.was_passed) measureName.value.asSlice() else null;
    performance_timeline.clearEntries(try timeline(instance), .measure, name);
}

/// A `(DOMString or DOMHighResTimeStamp)` value, converted.
const MarkValue = union(enum) {
    name: []u8,
    timestamp: f64,

    fn deinit(self: MarkValue, allocator: std.mem.Allocator) void {
        switch (self) {
            .name => |n| allocator.free(n),
            .timestamp => {},
        }
    }
};

/// WebIDL's union conversion for `(DOMString or DOMHighResTimeStamp)`: a
/// Number is the (restricted) double, anything else ToString.
fn convertMarkValue(realm: runtime.Context, value: runtime.JSValue, allocator: std.mem.Allocator) !MarkValue {
    if (engine.typeOf(realm, value) == .number) {
        const number = try engine.convertToUnrestrictedDouble(realm, value);
        if (!std.math.isFinite(number)) return error.TypeError;
        return .{ .timestamp = number };
    }
    return .{ .name = try engine.convertToDOMString(realm, value, allocator) };
}

/// PerformanceMeasureOptions, as measure() reads it: each member converted,
/// `detail` held until the measure is made.
const MeasureOptions = struct {
    detail: ?engine.Owned = null,
    duration: ?f64 = null,
    end: ?MarkValue = null,
    start: ?MarkValue = null,

    fn deinit(self: *MeasureOptions, allocator: std.mem.Allocator) void {
        if (self.detail) |detail| detail.release();
        if (self.end) |end| end.deinit(allocator);
        if (self.start) |start| start.deinit(allocator);
    }

    fn anyExists(self: *const MeasureOptions) bool {
        return self.detail != null or self.duration != null or self.end != null or self.start != null;
    }
};

/// The dictionary conversion of `object` to PerformanceMeasureOptions:
/// members in lexicographic order (detail, duration, end, start), each Get
/// once; undefined is "not present"; what a getter throws propagates.
fn convertMeasureOptions(realm: runtime.Context, object: runtime.JSValue, allocator: std.mem.Allocator) !MeasureOptions {
    var options: MeasureOptions = .{};
    errdefer options.deinit(allocator);
    if (engine.typeOf(realm, object) != .object) return options;
    {
        const detail = try engine.getProperty(realm, object, "detail");
        if (engine.typeOf(realm, detail.value) == .undefined) detail.release() else options.detail = detail;
    }
    {
        const duration = try engine.getProperty(realm, object, "duration");
        defer duration.release();
        if (engine.typeOf(realm, duration.value) != .undefined) {
            const number = try engine.convertToUnrestrictedDouble(realm, duration.value);
            if (!std.math.isFinite(number)) return error.TypeError;
            options.duration = number;
        }
    }
    {
        const end = try engine.getProperty(realm, object, "end");
        defer end.release();
        if (engine.typeOf(realm, end.value) != .undefined) options.end = try convertMarkValue(realm, end.value, allocator);
    }
    {
        const start = try engine.getProperty(realm, object, "start");
        defer start.release();
        if (engine.typeOf(realm, start.value) != .undefined) options.start = try convertMarkValue(realm, start.value, allocator);
    }
    return options;
}

/// User Timing 3.2 "convert a name to a timestamp".
fn convertNameToTimestamp(instance: *runtime.Instance, name: []const u8) !f64 {
    // 1. Not a Window's global: TypeError.
    if (!instance.ctx.isWindow()) return error.TypeError;
    // 2.
    if (std.mem.eql(u8, name, "navigationStart")) return 0;
    // 3-6. TODO(perftimeline): PerformanceTiming's values come from the
    // navigation's timing (Navigation Timing); until they are recorded every
    // other attribute reads 0, which step 5 makes an InvalidAccessError.
    return error.InvalidAccessError;
}

/// User Timing 3.1 "convert a mark to a timestamp".
fn convertMarkToTimestamp(instance: *runtime.Instance, mark: MarkValue) !f64 {
    switch (mark) {
        .name => |name| {
            // 1. A PerformanceTiming attribute's name.
            if (performance_timeline.isPerformanceTimingAttribute(name)) return convertNameToTimestamp(instance, name);
            // 2. The most recent mark of that name, or SyntaxError.
            return performance_timeline.mostRecentStartTime(try timeline(instance), .mark, name) orelse error.SyntaxError;
        },
        // 3. A negative timestamp is a TypeError.
        .timestamp => |timestamp| {
            if (timestamp < 0) return error.TypeError;
            return timestamp;
        },
    }
}

/// Operation: measure (User Timing 2.1.3)
pub fn call_measure(instance: *runtime.Instance, measureName: runtime.DOMString, startOrMeasureOptions: webidl.Opt(runtime.JSValue), endMark: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    const allocator = instance.ctx.allocator;
    const realm = engine.currentRealm() orelse instance.ctx;

    // The union `(DOMString or PerformanceMeasureOptions)`, default {}:
    // undefined, null and any object convert to the dictionary, anything
    // else to a string.
    var options: ?MeasureOptions = null;
    var start_name: ?[]u8 = null;
    defer if (options) |*o| o.deinit(allocator);
    defer if (start_name) |n| allocator.free(n);
    if (!startOrMeasureOptions.was_passed) {
        options = .{};
    } else switch (engine.typeOf(realm, startOrMeasureOptions.value)) {
        .undefined, .null => options = .{},
        .object => options = try convertMeasureOptions(realm, startOrMeasureOptions.value, allocator),
        else => start_name = try engine.convertToDOMString(realm, startOrMeasureOptions.value, allocator),
    }

    // 1. A PerformanceMeasureOptions with at least one member present.
    if (options) |*o| {
        if (o.anyExists()) {
            // 1.1.
            if (endMark.was_passed) return error.TypeError;
            // 1.2.
            if (o.start == null and o.end == null) return error.TypeError;
            // 1.3.
            if (o.start != null and o.duration != null and o.end != null) return error.TypeError;
        }
    }

    // 2. end time.
    const end_time: f64 = blk: {
        // 2.1.
        if (endMark.was_passed) {
            const copy = try allocator.dupe(u8, endMark.value.asSlice());
            defer allocator.free(copy);
            break :blk try convertMarkToTimestamp(instance, .{ .name = copy });
        }
        if (options) |*o| {
            // 2.2.
            if (o.end) |end| break :blk try convertMarkToTimestamp(instance, end);
            // 2.3.
            if (o.start != null and o.duration != null) {
                const start = try convertMarkToTimestamp(instance, o.start.?);
                const duration = try convertMarkToTimestamp(instance, .{ .timestamp = o.duration.? });
                break :blk start + duration;
            }
        }
        // 2.4. now().
        break :blk try call_now(instance);
    };

    // 3. start time.
    const start_time: f64 = blk: {
        if (options) |*o| {
            // 3.1.
            if (o.start) |start| break :blk try convertMarkToTimestamp(instance, start);
            // 3.2.
            if (o.duration != null and o.end != null) {
                const duration = try convertMarkToTimestamp(instance, .{ .timestamp = o.duration.? });
                const end = try convertMarkToTimestamp(instance, o.end.?);
                break :blk end - duration;
            }
        }
        // 3.3.
        if (start_name) |name| break :blk try convertMarkToTimestamp(instance, .{ .name = name });
        // 3.4.
        break :blk 0;
    };

    // 9. detail: StructuredSerialize, then StructuredDeserialize in the
    // current realm (done first, so that a DataCloneError makes no entry).
    // StructuredSerializeForStorage: the same as StructuredSerialize but for
    // a SharedArrayBuffer, which a non-isolated realm does not have.
    var detail: ?engine.Owned = null;
    defer if (detail) |d| d.release();
    if (options) |*o| {
        if (o.detail) |source| {
            const record = try engine.structuredSerializeForStorage(realm, source.value, allocator);
            defer allocator.free(record);
            detail = try engine.structuredDeserialize(realm, record);
        }
    }

    // 4-9. A new PerformanceMeasure in this's relevant realm.
    const entry = try performance_timeline.createMeasure(instance.ctx, measureName.asSlice(), start_time, end_time, if (detail) |d| d.value else null);
    const generation = runtime.SlabAllocator.generationOf(entry);
    errdefer entry.releaseIfUnwrapped(generation);
    // 10-11. Queue it (which adds it to the buffer).
    try performance_timeline.queueEntry(try timeline(instance), entry);
    // 12.
    return entry;
}

// ============================================================================
// Resource Timing
// ============================================================================

/// Operation: clearResourceTimings (Resource Timing 3.4): every
/// PerformanceResourceTiming out of the buffer, its current size 0.
pub fn call_clearResourceTimings(instance: *runtime.Instance) anyerror!void {
    performance_timeline.clearResourceTimings(try timeline(instance));
}

/// Operation: setResourceTimingBufferSize (Resource Timing 3.4): the
/// buffer's size limit; entries already in it stay.
pub fn call_setResourceTimingBufferSize(instance: *runtime.Instance, maxSize: u32) anyerror!void {
    performance_timeline.setResourceTimingBufferSize(try timeline(instance), maxSize);
}

/// Operation: measureUserAgentSpecificMemory
pub fn call_measureUserAgentSpecificMemory(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

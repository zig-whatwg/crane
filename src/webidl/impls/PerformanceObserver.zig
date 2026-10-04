//! Implementation for PerformanceObserver interface
//!
//! Spec: https://w3c.github.io/performance-timeline/#the-performanceobserver-interface
//!
//! An observer's concepts - its callback, observer buffer, observer type,
//! requires dropped entries, and its registration's options list - are a
//! `dom.performance_timeline.Observer`, kept here; its relevant global's
//! timeline lists it while it is registered, and the PerformanceObserver
//! task (in that module) delivers to it.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceObserver = interfaces.PerformanceObserver;

pub const State = PerformanceObserver.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    observer: performance_timeline.Observer,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installExceptionReporter(&reportException);
}

/// HTML "report an exception" for `global`: an observer callback threw.
fn reportException(global: *runtime.Instance, info: *const engine.ErrorInfo) void {
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .observer = performance_timeline.Observer.init(allocator, instance) };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// Deinitialize instance: off its global's list (if that is still there),
/// its callback released.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.observer.deinit();
    internal.allocator.destroy(internal);
    state.own._internal = null;
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

fn observerOf(instance: *runtime.Instance) !*performance_timeline.Observer {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return &internal.observer;
}

/// Constructor: a new PerformanceObserver with its observer callback set to
/// `callback` (OWNED from here: the binding hands the converted function
/// over).
pub fn call_constructor(ctx: runtime.Context, callback: callbacks.PerformanceObserverCallback) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &PerformanceObserver.vtable, ctx);
    const observer = observerOf(instance) catch unreachable;
    observer.callback = engine.takeCallbackFunction(@ptrCast(callback));
    return instance;
}

/// The member a global keeps its frozen array of supported entry types in
/// (engine.traceValue on the global object).
const supported_entry_types_slot: engine.TracedSlot = .{ .name = "supportedEntryTypes" };

/// Static getter for supportedEntryTypes (4.5): the environment settings
/// object's global object's frozen array of supported entry types -
/// [SameObject]: made once per global, on the first read, and kept by an
/// edge from the global (the static-call vehicle carries the current realm,
/// which a static attribute's settings object is).
pub fn get_static_supportedEntryTypes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const realm = instance.ctx;
    const global = performance_timeline.globalOf(realm);
    if (global) |g| {
        if (engine.tracedValue(g, supported_entry_types_slot)) |kept| return kept.take();
    }
    const types = performance_timeline.supportedEntryTypes();
    var values: [@typeInfo(performance_timeline.EntryType).@"enum".fields.len]runtime.JSValue = undefined;
    for (types, 0..) |t, i| values[i] = .{ .string = .{ .data = t.name(), .owned = false } };
    const array = try engine.createFrozenArray(realm, values[0..types.len]);
    if (global) |g| engine.traceValue(g, array.value, supported_entry_types_slot);
    return array.take();
}

/// Operation: observe (4.2)
pub fn call_observe(instance: *runtime.Instance, options: webidl.Opt(dictionaries.PerformanceObserverInit)) anyerror!void {
    const observer = try observerOf(instance);
    const init_options: dictionaries.PerformanceObserverInit = if (options.was_passed) options.value else .{};
    // 1. relevantGlobal: this's relevant global object.
    // 2. Neither entryTypes nor type: TypeError.
    if (init_options.entryTypes == null and init_options.type == null) return error.TypeError;
    // 3. entryTypes with any other member: TypeError.
    if (init_options.entryTypes != null and (init_options.type != null or init_options.buffered != null or init_options.durationThreshold != null)) return error.TypeError;
    // 4. Update or check the observer type.
    if (observer.observer_type == .undefined) {
        if (init_options.entryTypes != null) observer.observer_type = .multiple;
        if (init_options.type != null) observer.observer_type = .single;
    }
    if (observer.observer_type == .single and init_options.entryTypes != null) return error.InvalidModificationError;
    if (observer.observer_type == .multiple and init_options.type != null) return error.InvalidModificationError;
    // 5.
    observer.requires_dropped_entries = true;
    // 6-7. On the relevant global's timeline; a global with no Performance
    // of its own yet (a worker's) has none to register on.
    const timeline = performance_timeline.timelineOf(instance.ctx) orelse return;
    var entry_types: ?[]const []const u8 = null;
    var names: std.ArrayListUnmanaged([]const u8) = .empty;
    defer names.deinit(instance.ctx.allocator);
    if (init_options.entryTypes) |list| {
        for (list) |entry_type| try names.append(instance.ctx.allocator, entry_type.asSlice());
        entry_types = names.items;
    }
    try performance_timeline.observe(timeline, observer, .{
        .entry_types = entry_types,
        .single_type = if (init_options.type) |t| t.asSlice() else null,
        .buffered = init_options.buffered orelse false,
    });
}

/// Operation: disconnect (4.4)
pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
    (try observerOf(instance)).disconnect();
}

/// Operation: takeRecords (4.3): a copy of the observer buffer, as an Array
/// of the current realm, and the buffer emptied - in that order, so that the
/// Array holds the entries before the observer lets them go.
pub fn call_takeRecords(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const observer = try observerOf(instance);
    const realm = engine.currentRealm() orelse instance.ctx;
    const records = try engine.createSequenceOfPlatformObjects(realm, observer.buffer.items);
    observer.emptyBuffer();
    return records.take();
}

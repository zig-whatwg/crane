//! Implementation for PerformanceObserverEntryList interface
//!
//! Spec: https://w3c.github.io/performance-timeline/#performanceobserverentrylist-interface
//!
//! The PerformanceObserver task makes one per delivery, with its entry list
//! set to the observer buffer's entries (`dom.performance_timeline`, through
//! the hook this impl installs: the list has no constructor).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const engine = @import("engine");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceObserverEntryList = interfaces.PerformanceObserverEntryList;

pub const State = PerformanceObserverEntryList.State;

pub const ImplError = error{
    NotImplemented,
};

/// The entry list, each entry kept by an edge from the list's wrapper.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    entries: []*runtime.Instance,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installEntryLists(.{ .create = &createEntryList });
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

/// Deinitialize instance. A list freed unwrapped lets its waiting edges go;
/// for one the collector frees, the edges went with its wrapper.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    for (internal.entries) |entry| performance_timeline.releaseEntry(instance, entry);
    internal.allocator.free(internal.entries);
    internal.allocator.destroy(internal);
    state.own._internal = null;
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The observer task's step 3.3.5: a new list in `realm` whose entry list is
/// `list`, each entry kept by the list.
fn createEntryList(realm: runtime.Context, list: []const *runtime.Instance) anyerror!*runtime.Instance {
    const allocator = realm.allocator;
    const instance = try init(allocator, State, &PerformanceObserverEntryList.vtable, realm);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator, .entries = try allocator.dupe(*runtime.Instance, list) };
    instance.getState(State).own._internal = internal;
    for (internal.entries) |entry| performance_timeline.holdEntry(instance, entry);
    return instance;
}

/// "filter buffer by name and type" over this's entry list, as an Array of
/// the current realm.
fn filtered(instance: *runtime.Instance, name: ?[]const u8, entry_type: ?[]const u8) !runtime.JSValue {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const allocator = instance.ctx.allocator;
    var result: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer result.deinit(allocator);
    try performance_timeline.filterBuffer(allocator, &result, internal.entries, name, entry_type);
    const realm = engine.currentRealm() orelse instance.ctx;
    const array = try engine.createSequenceOfPlatformObjects(realm, result.items);
    return array.take();
}

/// Operation: getEntries
pub fn call_getEntries(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return filtered(instance, null, null);
}

/// Operation: getEntriesByType
pub fn call_getEntriesByType(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!runtime.JSValue {
    return filtered(instance, null, @"type".asSlice());
}

/// Operation: getEntriesByName
pub fn call_getEntriesByName(instance: *runtime.Instance, name: runtime.DOMString, @"type": webidl.Opt(runtime.DOMString)) anyerror!runtime.JSValue {
    return filtered(instance, name.asSlice(), if (@"type".was_passed) @"type".value.asSlice() else null);
}

//! Implementation for StylePropertyMapReadOnly interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const StylePropertyMapReadOnly = interfaces.StylePropertyMapReadOnly;

pub const State = StylePropertyMapReadOnly.State;

pub const ImplError = error{
    NotImplemented,
};

const dom = @import("dom");
pub const construction_args = .{"property_map_source"};
pub const InternalState = struct { map: dom.style.typed_om.PropertyMap };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    if (!@hasField(@TypeOf(args), "property_map_source")) return error.InvalidStateError;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
    internal.* = .{ .map = try dom.style.typed_om.PropertyMap.init(instance, args.property_map_source) };
    instance.getState(State).own._internal = internal;
    internal.map.trace(instance);
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.map.deinit(instance);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

pub fn installHooks() void {
    dom.style.hooks.install(.{ .property_map_of = propertyMap });
}

fn propertyMap(instance: *runtime.Instance) ?*dom.style.typed_om.PropertyMap {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.map;
}

pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    return dom.style.typed_om.mapSize(instance);
}

pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyerror!runtime.JSValue {
    var values = try dom.style.typed_om.mapGetAll(instance, property);
    defer values.deinit();
    if (values.values.items.len == 0) return .undefined;
    return .{ .instance = values.values.items[0] };
}

pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyerror!runtime.JSValue {
    var values = try dom.style.typed_om.mapGetAll(instance, property);
    defer values.deinit();
    return values.array();
}

pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) anyerror!bool {
    return dom.style.typed_om.mapHas(instance, property);
}

/// The generated pair-iterable bridge's live entry type. This map has no
/// live list: its value pairs are reified when asked, and taken once per
/// iterator (`iterableSnapshot`), so `getEntriesInternal` answers none.
pub const IterableEntry = struct {
    name: []const u8,
    value: []const u8,
};

/// The live entries the generated bridge asks for: none - the binding reads
/// `iterableSnapshot` instead (the generated `iterable_snapshot`).
pub fn getEntriesInternal(instance: *runtime.Instance) ?[]const IterableEntry {
    _ = instance;
    return null;
}

/// CSS Typed OM 1 3, the value pairs to iterate over: each declaration's
/// property and its reified values (`mapEntries`). WebIDL's iterator asks
/// for them again at each step; they are taken once, when an iterator or
/// forEach starts, as both shipping engines take them - Blink
/// (StylePropertyMapReadOnlyMainThread::CreateIterationSource) and WebKit
/// (StylePropertyMapReadOnly::Iterator's constructor); Firefox ships no
/// Typed OM (golden rule 2: the browsers decide; reifying every
/// declaration at every step would also make a computed map's iteration
/// quadratic). OWNED by the caller, who converts it, then deinits it.
pub fn iterableSnapshot(instance: *runtime.Instance) !dom.style.typed_om.IterableSnapshot {
    return dom.style.typed_om.mapEntries(instance);
}

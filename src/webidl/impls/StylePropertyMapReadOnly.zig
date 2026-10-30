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

/// Entry type for pair iterable support
/// Note: Using string types for V8 compatibility
pub const IterableEntry = struct {
    name: []const u8,
    value: []const u8, // CSSStyleValue as string representation
};

/// Get entries for pair iterable support (used by V8 for iteration)
pub fn getEntriesInternal(instance: *runtime.Instance) ?[]const IterableEntry {
    _ = instance;
    return null; // TODO: Implement when StylePropertyMapReadOnly is fully implemented
}

/// Q25's real sequence-valued iteration source. The old generated iterable
/// bridge above remains untouched until the routed binding support lands.
/// The caller owns this snapshot and must deinit after conversion.
pub fn iterableSnapshot(instance: *runtime.Instance) !dom.style.typed_om.IterableSnapshot {
    return dom.style.typed_om.mapEntries(instance);
}

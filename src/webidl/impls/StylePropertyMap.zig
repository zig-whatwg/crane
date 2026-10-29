//! Implementation for StylePropertyMap interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const StylePropertyMap = interfaces.StylePropertyMap;

pub const State = StylePropertyMap.State;

pub const ImplError = error{
    NotImplemented,
};

const dom = @import("dom");
pub const InternalState = struct {};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = instance;
    _ = allocator;
    _ = StateType;
    _ = args;
}

pub fn call_delete(instance: *runtime.Instance, property: runtime.USVString) anyerror!void {
    return dom.style.typed_om.mapDelete(instance, property);
}

pub fn call_append(instance: *runtime.Instance, property: runtime.USVString, values: []const runtime.JSValue) anyerror!void {
    return dom.style.typed_om.mapSet(instance, property, values, true);
}

pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    return dom.style.typed_om.mapClear(instance);
}

pub fn call_set(instance: *runtime.Instance, property: runtime.USVString, values: []const runtime.JSValue) anyerror!void {
    return dom.style.typed_om.mapSet(instance, property, values, false);
}

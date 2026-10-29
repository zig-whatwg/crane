//! Implementation for CSSStyleValue interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const css = @import("css");
const dom = @import("dom");
const CSSStyleValue = interfaces.CSSStyleValue;

pub const State = CSSStyleValue.State;

pub const ImplError = error{
    NotImplemented,
};

pub const construction_args = .{"native_style_value"};
pub const InternalState = struct { value: dom.style.typed_om.NativeValue };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (@hasField(@TypeOf(args), "native_style_value")) {
        const internal = try runtime.arenaOf(instance).create(InternalState);
        errdefer runtime.arenaOf(instance).destroy(InternalState, internal);
        internal.* = .{ .value = try dom.style.typed_om.NativeValue.init(allocator, args.native_style_value) };
        instance.getState(State).own._internal = internal;
    }
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.value.deinit(instance.ctx.allocator);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

pub fn installHooks() void {
    dom.style.hooks.install(.{ .style_value_of = nativeValue });
}

fn nativeValue(instance: *runtime.Instance) ?*dom.style.typed_om.NativeValue {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    return &internal.value;
}

/// Operation: parseAll (static)
pub fn call_static_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!runtime.JSValue {
    var values = try dom.style.typed_om.parseStyleValues(instance.ctx, property, cssText);
    defer values.deinit();
    return values.array();
}

/// Operation: parse (static)
pub fn call_static_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!*runtime.Instance {
    var values = try dom.style.typed_om.parseStyleValues(instance.ctx, property, cssText);
    defer values.deinit();
    if (values.values.items.len == 0) return error.TypeError;
    return values.values.items[0];
}

/// Stringifier - serialize method for toString
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    // CSS Typed OM §6: dispatch on the reified value's concrete type.
    // Subclass slots are reached only through their generated interface.
    if (instance.stateAs(interfaces.CSSKeywordValue.State) != null) {
        const value = try interfaces.CSSKeywordValue.get_value(instance);
        defer instance.ctx.allocator.free(value);
        // Chrome 156 and Safari 27 both pass cssKeywordValue.tentative.html's
        // escaped identifiers (aligned wpt.fyi, 2026-10-27). Typed OM §6.2's
        // raw-string wording predates this shared browser behavior.
        return css.serialize.serializeIdentifier(instance.ctx.allocator, value);
    }
    if (instance.stateAs(interfaces.CSSUnitValue.State) != null) {
        const unit = try interfaces.CSSUnitValue.get_unit(instance);
        defer instance.ctx.allocator.free(unit);
        return css.typed_om.numeric.serialize(instance.ctx.allocator, .{
            .value = try interfaces.CSSUnitValue.get_value(instance),
            .unit = css.typed_om.numeric.parseUnit(unit) orelse return error.TypeError,
        });
    }
    if (instance.stateAs(interfaces.CSSUnparsedValue.State) != null)
        return dom.style.typed_om.serializeUnparsed(instance);
    if (instance.stateAs(interfaces.CSSNumericValue.State) != null)
        return dom.style.typed_om.serializeNumeric(instance);
    if (nativeValue(instance)) |value| return value.serialize(instance.ctx.allocator);
    // KNOWN-INCOMPLETE: Q32 routes the CSSTransformValue family and
    // CSSPositionValue to a later batch. Other payload-free stubs retain
    // this legacy default too; they must not start throwing from toString().
    // TODO: CSS Typed OM "serialize a CSSStyleValue" (https://drafts.css-houdini.org/css-typed-om-1/#stylevalue-serialization). Until then, the placeholder - as a copy: the binding frees
    // the string toString() returns, and freeing a literal faulted in
    // Allocator.free's memset.
    return instance.ctx.allocator.dupe(u8, "[object]");
}

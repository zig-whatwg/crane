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

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: parseAll (static)
pub fn call_static_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!runtime.JSValue {
    _ = instance;
    _ = property;
    _ = cssText;
    return error.NotImplemented;
}

/// Operation: parse (static)
pub fn call_static_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!*runtime.Instance {
    _ = instance;
    _ = property;
    _ = cssText;
    return error.NotImplemented;
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
    if (instance.stateAs(interfaces.CSSMathValue.State) != null) return @import("dom").style.typed_om.serializeNumeric(instance);
    if (instance.stateAs(interfaces.CSSUnparsedValue.State) != null)
        return dom.style.typed_om.serializeUnparsed(instance);
    // TODO: CSS Typed OM "serialize a CSSStyleValue" (https://drafts.css-houdini.org/css-typed-om-1/#stylevalue-serialization). Until then, the placeholder - as a copy: the binding frees
    // the string toString() returns, and freeing a literal faulted in
    // Allocator.free's memset.
    return instance.ctx.allocator.dupe(u8, "[object]");
}

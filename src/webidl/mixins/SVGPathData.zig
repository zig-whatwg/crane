//! Auto-generated mixin: SVGPathData
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGPathDataImpl = @import("impls").SVGPathData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGPathDataSettings = @import("dictionaries").SVGPathDataSettings;
const SVGPathSegment = @import("interfaces").SVGPathSegment;

pub const impl = @import("impls").SVGPathData;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "SVGPathData")) {
        if (comptime @hasDecl(impls.SVGPathData, "installHooks")) impls.SVGPathData.installHooks();
    }
}

pub fn call_setPathData(instance: *runtime.Instance, pathData: runtime.JSValue) anyerror!void {
    return try SVGPathDataImpl.call_setPathData(instance, pathData);
}

pub fn call_getPathData(instance: *runtime.Instance, settings: webidl.Opt(SVGPathDataSettings)) anyerror!runtime.JSValue {
    return try SVGPathDataImpl.call_getPathData(instance, settings);
}

/// WebIDL interface types: the interface each interface-typed argument
/// and attribute value converts to - a TypeError unless the value implements
/// it (function, argument index - an attribute setter's value is 0 -,
/// interface; a nullable, sequence or record value by its elements').
pub const interface_arguments = .{
    .{ "call_setPathData", 0, "SVGPathSegment" },
};

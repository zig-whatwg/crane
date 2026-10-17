//! Auto-generated mixin: GeometryUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GeometryUtilsImpl = @import("impls").GeometryUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPoint = @import("interfaces").DOMPoint;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;

pub const impl = @import("impls").GeometryUtils;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "GeometryUtils")) {
        if (comptime @hasDecl(impls.GeometryUtils, "installHooks")) impls.GeometryUtils.installHooks();
    }
}

pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    return try GeometryUtilsImpl.call_convertQuadFromNode(instance, quad, from, options);
}

pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    return try GeometryUtilsImpl.call_convertRectFromNode(instance, rect, from, options);
}

pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(BoxQuadOptions)) anyerror!runtime.JSValue {
    return try GeometryUtilsImpl.call_getBoxQuads(instance, options);
}

pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    return try GeometryUtilsImpl.call_convertPointFromNode(instance, point, from, options);
}

/// WebIDL interface types: the interface each interface-typed argument
/// and attribute value converts to - a TypeError unless the value implements
/// it (function, argument index - an attribute setter's value is 0 -,
/// interface; a nullable, sequence or record value by its elements').
pub const interface_arguments = .{
    .{ "call_convertRectFromNode", 0, "DOMRectReadOnly" },
};

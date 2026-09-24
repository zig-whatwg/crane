//! Auto-generated mixin: CanvasUserInterface
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasUserInterfaceImpl = @import("impls").CanvasUserInterface;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const Path2D = @import("interfaces").Path2D;

pub const impl = @import("impls").CanvasUserInterface;

pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, element: *runtime.Instance) anyerror!void {
    return try CanvasUserInterfaceImpl.call_drawFocusIfNeeded(instance, element);
}

pub fn call_drawFocusIfNeeded__1(instance: *runtime.Instance, path: *runtime.Instance, element: *runtime.Instance) anyerror!void {
    if (comptime @hasDecl(CanvasUserInterfaceImpl, "call_drawFocusIfNeeded__1")) {
        return try CanvasUserInterfaceImpl.call_drawFocusIfNeeded__1(instance, path, element);
    } else {
        return error.NotImplemented;
    }
}

/// WebIDL overload sets: every overload of each overloaded operation,
/// in IDL order, for the overload resolution algorithm
/// (webidl.overload_resolution). The binding is installed for the first
/// overload and forwards to the one the arguments select.
pub const overloads = .{
    .{ "drawFocusIfNeeded", &[_]webidl.overload_resolution.Overload{
        .{ .function = "call_drawFocusIfNeeded", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)} }} },
        .{ .function = "call_drawFocusIfNeeded__1", .implemented = @hasDecl(CanvasUserInterfaceImpl, "call_drawFocusIfNeeded__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)} } } },
    } },
};

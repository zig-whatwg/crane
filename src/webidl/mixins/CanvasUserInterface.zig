//! Auto-generated mixin: CanvasUserInterface
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasUserInterfaceImpl = @import("impls").CanvasUserInterface;

// Re-export types from impl
pub const impl = @import("impls").CanvasUserInterface;

/// Arguments for drawFocusIfNeeded (WebIDL overloading)
pub const DrawFocusIfNeededArgs = union(enum) {
    /// drawFocusIfNeeded(element)
    Element: *runtime.Instance,
    /// drawFocusIfNeeded(path, element)
    Path2D_Element: struct {
        path: *runtime.Instance,
        element: *runtime.Instance,
    },
};

pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, args: DrawFocusIfNeededArgs) anyerror!void {
    return CanvasUserInterfaceImpl.call_drawFocusIfNeeded(instance, args);
}


//! Implementation for SVGElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const SVGElement = interfaces.SVGElement;
const ElementImpl = @import("Element.zig");

pub const State = SVGElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance: an SVG element is an Element, so its state is made
/// through the chain Element -> Node -> EventTarget. (A codegen stub's
/// `runtime.Instance.init` made a node with no Element or Node state, which
/// every operation on it reads.)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return ElementImpl.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance, through its ancestors' impls: EventTarget's side
/// tables are freed by its deinit.
pub fn deinit(instance: *runtime.Instance) void {
    ElementImpl.deinit(instance);
}

/// Getter for className
pub fn get_className(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ownerSVGElement
pub fn get_ownerSVGElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for viewportElement
pub fn get_viewportElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for style
pub fn get_style(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributeStyleMap
pub fn get_attributeStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for correspondingElement
pub fn get_correspondingElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for correspondingUseElement
pub fn get_correspondingUseElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for dataset
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nonce
pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for autofocus
pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for tabIndex
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for nonce
pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for autofocus
pub fn set_autofocus(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for tabIndex
pub fn set_tabIndex(instance: *runtime.Instance, value: i32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: blur
/// HTMLOrSVGElement: the unfocusing steps (src/html/focus.zig, shared with
/// HTMLElement and the mixin).
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    @import("html").focus.blurMethod(instance);
}

/// Operation: focus
/// HTMLOrSVGElement: the focusing steps (src/html/focus.zig, shared with
/// HTMLElement and the mixin).
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    // preventScroll and focusVisible: nothing is rendered or scrolled.
    _ = options;
    @import("html").focus.focusMethod(instance);
}

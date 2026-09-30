//! Implementation for HTMLOrSVGElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLOrSVGElement = interfaces.HTMLOrSVGElement;

pub const State = HTMLOrSVGElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    // HTMLOrSVGElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // HTMLOrSVGElement has no additional cleanup
    // Chain to parent class
    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
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

/// Operation: blur: the unfocusing steps (src/html/focus.zig). The live
/// binding is still each includer's impl (HTMLElement, SVGElement) until the
/// mixin joins codegen/inherited_mixins.zig; all three call one function.
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    @import("html").focus.blurMethod(instance);
}

/// Operation: focus: the focusing steps (src/html/focus.zig), as blur.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-focus
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    // preventScroll and focusVisible: nothing is rendered or scrolled.
    _ = options;
    @import("html").focus.focusMethod(instance);
}

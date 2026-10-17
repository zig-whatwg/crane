//! Implementation for MathMLElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const MathMLElement = interfaces.MathMLElement;

pub const State = MathMLElement.State;

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

// =============================================================================
// HTMLOrSVGOrMathMLElement members. HTML now includes the mixin in
// MathMLElement too. The mixin is not on codegen/inherited_mixins.zig yet,
// so its includers' impls answer its members; moving them into the mixin's
// impl (with the nonce slot into a src/dom store) is a queued follow-up.
// =============================================================================

/// Getter for dataset. Not implemented for MathML elements: HTMLElement's
/// DOMStringMap creation lives in its impl, not in a shared helper.
pub fn get_dataset(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nonce. Not implemented: the nonce slot is per includer impl.
pub fn get_nonce(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for nonce. Not implemented: the nonce slot is per includer impl.
pub fn set_nonce(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Getter for tabIndex. Not implemented for MathML elements: HTMLElement's
/// tabindex rules live in its impl, not in a shared helper.
pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: focus: the focusing steps (src/html/focus.zig), as
/// HTMLElement and SVGElement run them.
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-focus
pub fn call_focus(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FocusOptions)) anyerror!void {
    // preventScroll and focusVisible: nothing is rendered or scrolled.
    _ = options;
    @import("html").focus.focusMethod(instance);
}

/// Operation: blur: the unfocusing steps (src/html/focus.zig).
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-blur
pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    @import("html").focus.blurMethod(instance);
}

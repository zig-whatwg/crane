//! Auto-generated mixin: HTMLOrSVGElement
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLOrSVGElementImpl = @import("impls").HTMLOrSVGElement;

// Re-export types from impl
pub const impl = @import("impls").HTMLOrSVGElement;

pub fn get_dataset(instance: *runtime.Instance) !*runtime.Instance {
    return HTMLOrSVGElementImpl.get_dataset(instance);
}

pub fn get_nonce(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return HTMLOrSVGElementImpl.get_nonce(instance);
}

pub fn set_nonce(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return HTMLOrSVGElementImpl.set_nonce(instance, value);
}

pub fn get_autofocus(instance: *runtime.Instance) anyerror!bool {
    return HTMLOrSVGElementImpl.get_autofocus(instance);
}

pub fn set_autofocus(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLOrSVGElementImpl.set_autofocus(instance, value);
}

pub fn get_tabIndex(instance: *runtime.Instance) anyerror!i32 {
    return HTMLOrSVGElementImpl.get_tabIndex(instance);
}

pub fn set_tabIndex(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLOrSVGElementImpl.set_tabIndex(instance, value);
}

pub fn call_focus(instance: *runtime.Instance, options: dictionaries.FocusOptions) anyerror!void {
    return HTMLOrSVGElementImpl.call_focus(instance, options);
}

pub fn call_blur(instance: *runtime.Instance) anyerror!void {
    return HTMLOrSVGElementImpl.call_blur(instance);
}


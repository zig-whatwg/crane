//! Auto-generated mixin: ElementContentEditable
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ElementContentEditableImpl = @import("impls").ElementContentEditable;

// Re-export types from impl
pub const impl = @import("impls").ElementContentEditable;

pub fn get_contentEditable(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ElementContentEditableImpl.get_contentEditable(instance);
}

pub fn set_contentEditable(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ElementContentEditableImpl.set_contentEditable(instance, value);
}

pub fn get_enterKeyHint(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ElementContentEditableImpl.get_enterKeyHint(instance);
}

pub fn set_enterKeyHint(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ElementContentEditableImpl.set_enterKeyHint(instance, value);
}

pub fn get_isContentEditable(instance: *runtime.Instance) anyerror!bool {
    return ElementContentEditableImpl.get_isContentEditable(instance);
}

pub fn get_inputMode(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ElementContentEditableImpl.get_inputMode(instance);
}

pub fn set_inputMode(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ElementContentEditableImpl.set_inputMode(instance, value);
}

pub fn get_virtualKeyboardPolicy(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return ElementContentEditableImpl.get_virtualKeyboardPolicy(instance);
}

pub fn set_virtualKeyboardPolicy(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return ElementContentEditableImpl.set_virtualKeyboardPolicy(instance, value);
}


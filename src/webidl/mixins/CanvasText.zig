//! Auto-generated mixin: CanvasText
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasTextImpl = @import("impls").CanvasText;

// Re-export types from impl
pub const impl = @import("impls").CanvasText;

pub fn call_measureText(instance: *runtime.Instance, text: typedefs.DOMString) !*runtime.Instance {
    return CanvasTextImpl.call_measureText(instance, text);
}

pub fn call_strokeText(instance: *runtime.Instance, text: typedefs.DOMString, x: runtime.JSValue, y: runtime.JSValue, maxWidth: runtime.JSValue) anyerror!void {
    return CanvasTextImpl.call_strokeText(instance, text, x, y, maxWidth);
}

pub fn call_fillText(instance: *runtime.Instance, text: typedefs.DOMString, x: runtime.JSValue, y: runtime.JSValue, maxWidth: runtime.JSValue) anyerror!void {
    return CanvasTextImpl.call_fillText(instance, text, x, y, maxWidth);
}


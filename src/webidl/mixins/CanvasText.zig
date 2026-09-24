//! Auto-generated mixin: CanvasText
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasTextImpl = @import("impls").CanvasText;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TextMetrics = @import("interfaces").TextMetrics;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").CanvasText;

pub fn call_measureText(instance: *runtime.Instance, text: DOMString) anyerror!*runtime.Instance {
    return try CanvasTextImpl.call_measureText(instance, text);
}

pub fn call_strokeText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: webidl.Opt(f64)) anyerror!void {
    return try CanvasTextImpl.call_strokeText(instance, text, x, y, maxWidth);
}

pub fn call_fillText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: webidl.Opt(f64)) anyerror!void {
    return try CanvasTextImpl.call_fillText(instance, text, x, y, maxWidth);
}

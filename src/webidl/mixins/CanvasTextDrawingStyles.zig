//! Auto-generated mixin: CanvasTextDrawingStyles
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasTextDrawingStylesImpl = @import("impls").CanvasTextDrawingStyles;

// Re-export types from impl
pub const impl = @import("impls").CanvasTextDrawingStyles;

pub fn get_lang(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasTextDrawingStylesImpl.get_lang(instance);
}

pub fn set_lang(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasTextDrawingStylesImpl.set_lang(instance, value);
}

pub fn get_font(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasTextDrawingStylesImpl.get_font(instance);
}

pub fn set_font(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasTextDrawingStylesImpl.set_font(instance, value);
}

pub fn get_textAlign(instance: *runtime.Instance) anyerror!enums.CanvasTextAlign {
    return CanvasTextDrawingStylesImpl.get_textAlign(instance);
}

pub fn set_textAlign(instance: *runtime.Instance, value: enums.CanvasTextAlign) !void {
    return CanvasTextDrawingStylesImpl.set_textAlign(instance, value);
}

pub fn get_textBaseline(instance: *runtime.Instance) anyerror!enums.CanvasTextBaseline {
    return CanvasTextDrawingStylesImpl.get_textBaseline(instance);
}

pub fn set_textBaseline(instance: *runtime.Instance, value: enums.CanvasTextBaseline) !void {
    return CanvasTextDrawingStylesImpl.set_textBaseline(instance, value);
}

pub fn get_direction(instance: *runtime.Instance) anyerror!enums.CanvasDirection {
    return CanvasTextDrawingStylesImpl.get_direction(instance);
}

pub fn set_direction(instance: *runtime.Instance, value: enums.CanvasDirection) !void {
    return CanvasTextDrawingStylesImpl.set_direction(instance, value);
}

pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasTextDrawingStylesImpl.get_letterSpacing(instance);
}

pub fn set_letterSpacing(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasTextDrawingStylesImpl.set_letterSpacing(instance, value);
}

pub fn get_fontKerning(instance: *runtime.Instance) anyerror!enums.CanvasFontKerning {
    return CanvasTextDrawingStylesImpl.get_fontKerning(instance);
}

pub fn set_fontKerning(instance: *runtime.Instance, value: enums.CanvasFontKerning) !void {
    return CanvasTextDrawingStylesImpl.set_fontKerning(instance, value);
}

pub fn get_fontStretch(instance: *runtime.Instance) anyerror!enums.CanvasFontStretch {
    return CanvasTextDrawingStylesImpl.get_fontStretch(instance);
}

pub fn set_fontStretch(instance: *runtime.Instance, value: enums.CanvasFontStretch) !void {
    return CanvasTextDrawingStylesImpl.set_fontStretch(instance, value);
}

pub fn get_fontVariantCaps(instance: *runtime.Instance) anyerror!enums.CanvasFontVariantCaps {
    return CanvasTextDrawingStylesImpl.get_fontVariantCaps(instance);
}

pub fn set_fontVariantCaps(instance: *runtime.Instance, value: enums.CanvasFontVariantCaps) !void {
    return CanvasTextDrawingStylesImpl.set_fontVariantCaps(instance, value);
}

pub fn get_textRendering(instance: *runtime.Instance) anyerror!enums.CanvasTextRendering {
    return CanvasTextDrawingStylesImpl.get_textRendering(instance);
}

pub fn set_textRendering(instance: *runtime.Instance, value: enums.CanvasTextRendering) !void {
    return CanvasTextDrawingStylesImpl.set_textRendering(instance, value);
}

pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasTextDrawingStylesImpl.get_wordSpacing(instance);
}

pub fn set_wordSpacing(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasTextDrawingStylesImpl.set_wordSpacing(instance, value);
}


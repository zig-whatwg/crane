//! Auto-generated mixin: CanvasTextDrawingStyles
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasTextDrawingStylesImpl = @import("impls").CanvasTextDrawingStyles;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasTextBaseline = @import("enums").CanvasTextBaseline;
const CanvasTextAlign = @import("enums").CanvasTextAlign;
const CanvasFontVariantCaps = @import("enums").CanvasFontVariantCaps;
const CanvasFontStretch = @import("enums").CanvasFontStretch;
const CanvasDirection = @import("enums").CanvasDirection;
const CanvasFontKerning = @import("enums").CanvasFontKerning;
const CanvasTextRendering = @import("enums").CanvasTextRendering;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").CanvasTextDrawingStyles;

pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasTextDrawingStylesImpl.get_lang(instance);
}

pub fn set_lang(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_lang(instance, value);
}

pub fn get_font(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasTextDrawingStylesImpl.get_font(instance);
}

pub fn set_font(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_font(instance, value);
}

pub fn get_textAlign(instance: *runtime.Instance) anyerror!CanvasTextAlign {
    return try CanvasTextDrawingStylesImpl.get_textAlign(instance);
}

pub fn set_textAlign(instance: *runtime.Instance, value: CanvasTextAlign) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_textAlign(instance, value);
}

pub fn get_textBaseline(instance: *runtime.Instance) anyerror!CanvasTextBaseline {
    return try CanvasTextDrawingStylesImpl.get_textBaseline(instance);
}

pub fn set_textBaseline(instance: *runtime.Instance, value: CanvasTextBaseline) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_textBaseline(instance, value);
}

pub fn get_direction(instance: *runtime.Instance) anyerror!CanvasDirection {
    return try CanvasTextDrawingStylesImpl.get_direction(instance);
}

pub fn set_direction(instance: *runtime.Instance, value: CanvasDirection) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_direction(instance, value);
}

pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasTextDrawingStylesImpl.get_letterSpacing(instance);
}

pub fn set_letterSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_letterSpacing(instance, value);
}

pub fn get_fontKerning(instance: *runtime.Instance) anyerror!CanvasFontKerning {
    return try CanvasTextDrawingStylesImpl.get_fontKerning(instance);
}

pub fn set_fontKerning(instance: *runtime.Instance, value: CanvasFontKerning) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_fontKerning(instance, value);
}

pub fn get_fontStretch(instance: *runtime.Instance) anyerror!CanvasFontStretch {
    return try CanvasTextDrawingStylesImpl.get_fontStretch(instance);
}

pub fn set_fontStretch(instance: *runtime.Instance, value: CanvasFontStretch) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_fontStretch(instance, value);
}

pub fn get_fontVariantCaps(instance: *runtime.Instance) anyerror!CanvasFontVariantCaps {
    return try CanvasTextDrawingStylesImpl.get_fontVariantCaps(instance);
}

pub fn set_fontVariantCaps(instance: *runtime.Instance, value: CanvasFontVariantCaps) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_fontVariantCaps(instance, value);
}

pub fn get_textRendering(instance: *runtime.Instance) anyerror!CanvasTextRendering {
    return try CanvasTextDrawingStylesImpl.get_textRendering(instance);
}

pub fn set_textRendering(instance: *runtime.Instance, value: CanvasTextRendering) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_textRendering(instance, value);
}

pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasTextDrawingStylesImpl.get_wordSpacing(instance);
}

pub fn set_wordSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasTextDrawingStylesImpl.set_wordSpacing(instance, value);
}

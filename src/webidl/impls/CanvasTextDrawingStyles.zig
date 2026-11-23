//! Implementation for CanvasTextDrawingStyles interface
//!
//! HTML 4.12.5.1.5: the text styles of whichever 2D context includes this
//! mixin, in its drawing state (dom.canvas_2d.DrawingState). The
//! keyword-valued attributes "on getting, must return the current value"
//! and "on setting, the current value must be changed to the new value"
//! (WebIDL has already dropped a string that names no value).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const CanvasTextDrawingStyles = interfaces.CanvasTextDrawingStyles;

pub const State = CanvasTextDrawingStyles.State;

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

/// The 2D context's state; an InvalidStateError for one whose state is gone
/// (or an includer that keeps none - PaintRenderingContext2D, which no paint
/// worklet makes yet).
fn stateOf(instance: *runtime.Instance) !*dom.canvas_2d.Context2D {
    return dom.canvas_2d.stateOf(instance) orelse error.InvalidStateError;
}

/// An owned-string attribute's value: the drawing state's copy, or its
/// initial value.
fn textValue(instance: *runtime.Instance, text: ?[]const u8, comptime initial: []const u8) !runtime.DOMString {
    const value = text orelse return runtime.DOMString.initInterned(initial);
    return runtime.DOMString.initDupe(instance.ctx.allocator, value);
}

/// Getter for lang: "return this's lang" (initially "inherit").
pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return textValue(instance, (try stateOf(instance)).drawing.lang, dom.canvas_2d.DrawingState.initial_lang);
}

/// Getter for font: "the serialized form of the current font of the
/// context (with no 'line-height' component)" (initially "10px
/// sans-serif").
pub fn get_font(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return textValue(instance, (try stateOf(instance)).drawing.font, dom.canvas_2d.DrawingState.initial_font);
}

/// Getter for textAlign: the current value.
pub fn get_textAlign(instance: *runtime.Instance) anyerror!enums.CanvasTextAlign {
    return (try stateOf(instance)).drawing.text_align;
}

/// Getter for textBaseline: the current value.
pub fn get_textBaseline(instance: *runtime.Instance) anyerror!enums.CanvasTextBaseline {
    return (try stateOf(instance)).drawing.text_baseline;
}

/// Getter for direction: the current value.
pub fn get_direction(instance: *runtime.Instance) anyerror!enums.CanvasDirection {
    return (try stateOf(instance)).drawing.direction;
}

/// Getter for letterSpacing: "return the serialized form of this's letter spacing"
/// (initially "0px").
pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return textValue(instance, (try stateOf(instance)).drawing.letter_spacing, dom.canvas_2d.DrawingState.initial_spacing);
}

/// Getter for fontKerning: the current value.
pub fn get_fontKerning(instance: *runtime.Instance) anyerror!enums.CanvasFontKerning {
    return (try stateOf(instance)).drawing.font_kerning;
}

/// Getter for fontStretch: the current value.
pub fn get_fontStretch(instance: *runtime.Instance) anyerror!enums.CanvasFontStretch {
    return (try stateOf(instance)).drawing.font_stretch;
}

/// Getter for fontVariantCaps: the current value.
pub fn get_fontVariantCaps(instance: *runtime.Instance) anyerror!enums.CanvasFontVariantCaps {
    return (try stateOf(instance)).drawing.font_variant_caps;
}

/// Getter for textRendering: the current value.
pub fn get_textRendering(instance: *runtime.Instance) anyerror!enums.CanvasTextRendering {
    return (try stateOf(instance)).drawing.text_rendering;
}

/// Getter for wordSpacing: "return the serialized form of this's word spacing"
/// (initially "0px").
pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return textValue(instance, (try stateOf(instance)).drawing.word_spacing, dom.canvas_2d.DrawingState.initial_spacing);
}

/// Setter for lang: "set this's lang to the given value".
pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    try state.drawing.setText(state.allocator, "lang", value.asSlice(), dom.canvas_2d.DrawingState.initial_lang);
}

/// Setter for font: "must be parsed as a CSS <'font'> value (but without
/// supporting property-independent style sheet syntax like 'inherit'), and
/// the resulting font must be assigned to the context ... If the new value
/// is syntactically incorrect ..., then it must be ignored, without
/// assigning a new font value" (dom.canvas_2d.parseFont).
pub fn set_font(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    const font = (try dom.canvas_2d.parseFont(state.allocator, value.asSlice())) orelse return;
    defer state.allocator.free(font);
    try state.drawing.setText(state.allocator, "font", font, dom.canvas_2d.DrawingState.initial_font);
}

/// Setter for textAlign: the new value.
pub fn set_textAlign(instance: *runtime.Instance, value: enums.CanvasTextAlign) anyerror!void {
    (try stateOf(instance)).drawing.text_align = value;
}

/// Setter for textBaseline: the new value.
pub fn set_textBaseline(instance: *runtime.Instance, value: enums.CanvasTextBaseline) anyerror!void {
    (try stateOf(instance)).drawing.text_baseline = value;
}

/// Setter for direction: the new value.
pub fn set_direction(instance: *runtime.Instance, value: enums.CanvasDirection) anyerror!void {
    (try stateOf(instance)).drawing.direction = value;
}

/// Setter for letterSpacing: "1. Let parsed be the result of parsing the given value
/// as a CSS <length>. 2. If parsed is failure, then return. 3. Set this's
/// letter spacing to parsed."
pub fn set_letterSpacing(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    const parsed = (try dom.canvas_2d.parseLength(state.allocator, value.asSlice())) orelse return; // 1-2.
    defer state.allocator.free(parsed);
    try state.drawing.setText(state.allocator, "letter_spacing", parsed, dom.canvas_2d.DrawingState.initial_spacing); // 3.
}

/// Setter for fontKerning: the new value.
pub fn set_fontKerning(instance: *runtime.Instance, value: enums.CanvasFontKerning) anyerror!void {
    (try stateOf(instance)).drawing.font_kerning = value;
}

/// Setter for fontStretch: the new value.
pub fn set_fontStretch(instance: *runtime.Instance, value: enums.CanvasFontStretch) anyerror!void {
    (try stateOf(instance)).drawing.font_stretch = value;
}

/// Setter for fontVariantCaps: the new value.
pub fn set_fontVariantCaps(instance: *runtime.Instance, value: enums.CanvasFontVariantCaps) anyerror!void {
    (try stateOf(instance)).drawing.font_variant_caps = value;
}

/// Setter for textRendering: the new value.
pub fn set_textRendering(instance: *runtime.Instance, value: enums.CanvasTextRendering) anyerror!void {
    (try stateOf(instance)).drawing.text_rendering = value;
}

/// Setter for wordSpacing: "1. Let parsed be the result of parsing the given value
/// as a CSS <length>. 2. If parsed is failure, then return. 3. Set this's
/// word spacing to parsed."
pub fn set_wordSpacing(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    const parsed = (try dom.canvas_2d.parseLength(state.allocator, value.asSlice())) orelse return; // 1-2.
    defer state.allocator.free(parsed);
    try state.drawing.setText(state.allocator, "word_spacing", parsed, dom.canvas_2d.DrawingState.initial_spacing); // 3.
}

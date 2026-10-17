//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

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

pub const CanvasTextDrawingStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasTextDrawingStyles";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "lang", "get_lang", "set_lang" },
            .{ "font", "get_font", "set_font" },
            .{ "textAlign", "get_textAlign", "set_textAlign" },
            .{ "textBaseline", "get_textBaseline", "set_textBaseline" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "letterSpacing", "get_letterSpacing", "set_letterSpacing" },
            .{ "fontKerning", "get_fontKerning", "set_fontKerning" },
            .{ "fontStretch", "get_fontStretch", "set_fontStretch" },
            .{ "fontVariantCaps", "get_fontVariantCaps", "set_fontVariantCaps" },
            .{ "textRendering", "get_textRendering", "set_textRendering" },
            .{ "wordSpacing", "get_wordSpacing", "set_wordSpacing" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "lang", "get_lang", "set_lang" },
            .{ "font", "get_font", "set_font" },
            .{ "textAlign", "get_textAlign", "set_textAlign" },
            .{ "textBaseline", "get_textBaseline", "set_textBaseline" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "letterSpacing", "get_letterSpacing", "set_letterSpacing" },
            .{ "fontKerning", "get_fontKerning", "set_fontKerning" },
            .{ "fontStretch", "get_fontStretch", "set_fontStretch" },
            .{ "fontVariantCaps", "get_fontVariantCaps", "set_fontVariantCaps" },
            .{ "textRendering", "get_textRendering", "set_textRendering" },
            .{ "wordSpacing", "get_wordSpacing", "set_wordSpacing" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            lang: runtime.DOMString = undefined,
            font: runtime.DOMString = undefined,
            textAlign: enums.CanvasTextAlign = undefined,
            textBaseline: enums.CanvasTextBaseline = undefined,
            direction: enums.CanvasDirection = undefined,
            letterSpacing: runtime.DOMString = undefined,
            fontKerning: enums.CanvasFontKerning = undefined,
            fontStretch: enums.CanvasFontStretch = undefined,
            fontVariantCaps: enums.CanvasFontVariantCaps = undefined,
            textRendering: enums.CanvasTextRendering = undefined,
            wordSpacing: runtime.DOMString = undefined,
            _internal: ?*CanvasTextDrawingStylesImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CanvasTextDrawingStyles")) {
            if (comptime @hasDecl(impls.CanvasTextDrawingStyles, "installHooks")) impls.CanvasTextDrawingStyles.installHooks();
        }
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CanvasTextDrawingStylesImpl.get_lang(instance);
    }

    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try CanvasTextDrawingStylesImpl.set_lang(instance, value);
    }

    pub fn get_font(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CanvasTextDrawingStylesImpl.get_font(instance);
    }

    pub fn set_font(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

    pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CanvasTextDrawingStylesImpl.get_letterSpacing(instance);
    }

    pub fn set_letterSpacing(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

    pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CanvasTextDrawingStylesImpl.get_wordSpacing(instance);
    }

    pub fn set_wordSpacing(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try CanvasTextDrawingStylesImpl.set_wordSpacing(instance, value);
    }
};

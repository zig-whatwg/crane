//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasTextDrawingStylesImpl = @import("impls").CanvasTextDrawingStyles;
const CanvasTextBaseline = @import("enums").CanvasTextBaseline;
const CanvasTextAlign = @import("enums").CanvasTextAlign;
const CanvasFontVariantCaps = @import("enums").CanvasFontVariantCaps;
const CanvasFontStretch = @import("enums").CanvasFontStretch;
const CanvasDirection = @import("enums").CanvasDirection;
const CanvasFontKerning = @import("enums").CanvasFontKerning;
const CanvasTextRendering = @import("enums").CanvasTextRendering;

pub const CanvasTextDrawingStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasTextDrawingStyles";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            lang: runtime.DOMString = undefined,
            font: runtime.DOMString = undefined,
            textAlign: CanvasTextAlign = undefined,
            textBaseline: CanvasTextBaseline = undefined,
            direction: CanvasDirection = undefined,
            letterSpacing: runtime.DOMString = undefined,
            fontKerning: CanvasFontKerning = undefined,
            fontStretch: CanvasFontStretch = undefined,
            fontVariantCaps: CanvasFontVariantCaps = undefined,
            textRendering: CanvasTextRendering = undefined,
            wordSpacing: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasTextDrawingStyles, .{
        .deinit_fn = &deinit_wrapper,

        .get_direction = &get_direction,
        .get_font = &get_font,
        .get_fontKerning = &get_fontKerning,
        .get_fontStretch = &get_fontStretch,
        .get_fontVariantCaps = &get_fontVariantCaps,
        .get_lang = &get_lang,
        .get_letterSpacing = &get_letterSpacing,
        .get_textAlign = &get_textAlign,
        .get_textBaseline = &get_textBaseline,
        .get_textRendering = &get_textRendering,
        .get_wordSpacing = &get_wordSpacing,

        .set_direction = &set_direction,
        .set_font = &set_font,
        .set_fontKerning = &set_fontKerning,
        .set_fontStretch = &set_fontStretch,
        .set_fontVariantCaps = &set_fontVariantCaps,
        .set_lang = &set_lang,
        .set_letterSpacing = &set_letterSpacing,
        .set_textAlign = &set_textAlign,
        .set_textBaseline = &set_textBaseline,
        .set_textRendering = &set_textRendering,
        .set_wordSpacing = &set_wordSpacing,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasTextDrawingStylesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasTextDrawingStylesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

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

};

//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasTextDrawingStylesImpl = @import("../impls/CanvasTextDrawingStyles.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasTextDrawingStylesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_lang(state);
    }

    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_lang(state, value);
    }

    pub fn get_font(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_font(state);
    }

    pub fn set_font(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_font(state, value);
    }

    pub fn get_textAlign(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_textAlign(state);
    }

    pub fn set_textAlign(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_textAlign(state, value);
    }

    pub fn get_textBaseline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_textBaseline(state);
    }

    pub fn set_textBaseline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_textBaseline(state, value);
    }

    pub fn get_direction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_direction(state);
    }

    pub fn set_direction(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_direction(state, value);
    }

    pub fn get_letterSpacing(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_letterSpacing(state);
    }

    pub fn set_letterSpacing(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_letterSpacing(state, value);
    }

    pub fn get_fontKerning(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_fontKerning(state);
    }

    pub fn set_fontKerning(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_fontKerning(state, value);
    }

    pub fn get_fontStretch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_fontStretch(state);
    }

    pub fn set_fontStretch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_fontStretch(state, value);
    }

    pub fn get_fontVariantCaps(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_fontVariantCaps(state);
    }

    pub fn set_fontVariantCaps(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_fontVariantCaps(state, value);
    }

    pub fn get_textRendering(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_textRendering(state);
    }

    pub fn set_textRendering(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_textRendering(state, value);
    }

    pub fn get_wordSpacing(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasTextDrawingStylesImpl.get_wordSpacing(state);
    }

    pub fn set_wordSpacing(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasTextDrawingStylesImpl.set_wordSpacing(state, value);
    }

};

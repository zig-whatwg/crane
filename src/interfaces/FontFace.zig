//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceImpl = @import("../impls/FontFace.zig");

pub const FontFace = struct {
    pub const Meta = struct {
        pub const name = "FontFace";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            family: CSSOMString = undefined,
            style: CSSOMString = undefined,
            weight: CSSOMString = undefined,
            stretch: CSSOMString = undefined,
            unicodeRange: CSSOMString = undefined,
            featureSettings: CSSOMString = undefined,
            variationSettings: CSSOMString = undefined,
            display: CSSOMString = undefined,
            ascentOverride: CSSOMString = undefined,
            descentOverride: CSSOMString = undefined,
            lineGapOverride: CSSOMString = undefined,
            status: FontFaceLoadStatus = undefined,
            loaded: Promise<FontFace> = undefined,
            features: FontFaceFeatures = undefined,
            variations: FontFaceVariations = undefined,
            palettes: FontFacePalettes = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FontFace, .{
        .deinit_fn = &deinit_wrapper,

        .get_ascentOverride = &get_ascentOverride,
        .get_descentOverride = &get_descentOverride,
        .get_display = &get_display,
        .get_family = &get_family,
        .get_featureSettings = &get_featureSettings,
        .get_features = &get_features,
        .get_lineGapOverride = &get_lineGapOverride,
        .get_loaded = &get_loaded,
        .get_palettes = &get_palettes,
        .get_status = &get_status,
        .get_stretch = &get_stretch,
        .get_style = &get_style,
        .get_unicodeRange = &get_unicodeRange,
        .get_variationSettings = &get_variationSettings,
        .get_variations = &get_variations,
        .get_weight = &get_weight,

        .set_ascentOverride = &set_ascentOverride,
        .set_descentOverride = &set_descentOverride,
        .set_display = &set_display,
        .set_family = &set_family,
        .set_featureSettings = &set_featureSettings,
        .set_lineGapOverride = &set_lineGapOverride,
        .set_stretch = &set_stretch,
        .set_style = &set_style,
        .set_unicodeRange = &set_unicodeRange,
        .set_variationSettings = &set_variationSettings,
        .set_weight = &set_weight,

        .call_load = &call_load,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FontFaceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FontFaceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, family: anyopaque, source: anyopaque, descriptors: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try FontFaceImpl.constructor(state, family, source, descriptors);
        
        return instance;
    }

    pub fn get_family(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_family(state);
    }

    pub fn set_family(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_family(state, value);
    }

    pub fn get_style(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_style(state);
    }

    pub fn set_style(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_style(state, value);
    }

    pub fn get_weight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_weight(state);
    }

    pub fn set_weight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_weight(state, value);
    }

    pub fn get_stretch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_stretch(state);
    }

    pub fn set_stretch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_stretch(state, value);
    }

    pub fn get_unicodeRange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_unicodeRange(state);
    }

    pub fn set_unicodeRange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_unicodeRange(state, value);
    }

    pub fn get_featureSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_featureSettings(state);
    }

    pub fn set_featureSettings(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_featureSettings(state, value);
    }

    pub fn get_variationSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_variationSettings(state);
    }

    pub fn set_variationSettings(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_variationSettings(state, value);
    }

    pub fn get_display(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_display(state);
    }

    pub fn set_display(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_display(state, value);
    }

    pub fn get_ascentOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_ascentOverride(state);
    }

    pub fn set_ascentOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_ascentOverride(state, value);
    }

    pub fn get_descentOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_descentOverride(state);
    }

    pub fn set_descentOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_descentOverride(state, value);
    }

    pub fn get_lineGapOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_lineGapOverride(state);
    }

    pub fn set_lineGapOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FontFaceImpl.set_lineGapOverride(state, value);
    }

    pub fn get_status(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_status(state);
    }

    pub fn get_loaded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_loaded(state);
    }

    pub fn get_features(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_features(state);
    }

    pub fn get_variations(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_variations(state);
    }

    pub fn get_palettes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.get_palettes(state);
    }

    pub fn call_load(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontFaceImpl.call_load(state);
    }

};

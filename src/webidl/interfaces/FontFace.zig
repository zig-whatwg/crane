//! Generated from: css-font-loading.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontFaceImpl = @import("impls").FontFace;
const FontFaceLoadStatus = @import("enums").FontFaceLoadStatus;
const CSSOMString = @import("typedefs").CSSOMString;
const BufferSource = @import("typedefs").BufferSource;
const FontFaceVariations = @import("interfaces").FontFaceVariations;
const FontFacePalettes = @import("interfaces").FontFacePalettes;
const FontFaceFeatures = @import("interfaces").FontFaceFeatures;
const FontFaceDescriptors = @import("dictionaries").FontFaceDescriptors;

pub const FontFace = struct {
    pub const Meta = struct {
        pub const name = "FontFace";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "family", "get_family", "set_family" },
            .{ "style", "get_style", "set_style" },
            .{ "weight", "get_weight", "set_weight" },
            .{ "stretch", "get_stretch", "set_stretch" },
            .{ "unicodeRange", "get_unicodeRange", "set_unicodeRange" },
            .{ "featureSettings", "get_featureSettings", "set_featureSettings" },
            .{ "variationSettings", "get_variationSettings", "set_variationSettings" },
            .{ "display", "get_display", "set_display" },
            .{ "ascentOverride", "get_ascentOverride", "set_ascentOverride" },
            .{ "descentOverride", "get_descentOverride", "set_descentOverride" },
            .{ "lineGapOverride", "get_lineGapOverride", "set_lineGapOverride" },
            .{ "status", "get_status", null },
            .{ "loaded", "get_loaded", null },
            .{ "features", "get_features", null },
            .{ "variations", "get_variations", null },
            .{ "palettes", "get_palettes", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "load", "call_load", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "load",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "family", "get_family", "set_family" },
            .{ "style", "get_style", "set_style" },
            .{ "weight", "get_weight", "set_weight" },
            .{ "stretch", "get_stretch", "set_stretch" },
            .{ "unicodeRange", "get_unicodeRange", "set_unicodeRange" },
            .{ "featureSettings", "get_featureSettings", "set_featureSettings" },
            .{ "variationSettings", "get_variationSettings", "set_variationSettings" },
            .{ "display", "get_display", "set_display" },
            .{ "ascentOverride", "get_ascentOverride", "set_ascentOverride" },
            .{ "descentOverride", "get_descentOverride", "set_descentOverride" },
            .{ "lineGapOverride", "get_lineGapOverride", "set_lineGapOverride" },
            .{ "status", "get_status", null },
            .{ "loaded", "get_loaded", null },
            .{ "features", "get_features", null },
            .{ "variations", "get_variations", null },
            .{ "palettes", "get_palettes", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            loaded: runtime.Promise(FontFace) = undefined,
            features: *runtime.Instance = undefined,
            variations: *runtime.Instance = undefined,
            palettes: *runtime.Instance = undefined,
            _internal: ?*FontFaceImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontFaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontFaceImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, family: CSSOMString, source: *const anyopaque, descriptors: FontFaceDescriptors) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FontFaceImpl.call_constructor(allocator, ctx, family, source, descriptors);
    }

    pub fn get_family(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_family(instance);
    }

    pub fn set_family(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_family(instance, value);
    }

    pub fn get_style(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_style(instance);
    }

    pub fn set_style(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_style(instance, value);
    }

    pub fn get_weight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_weight(instance);
    }

    pub fn set_weight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_weight(instance, value);
    }

    pub fn get_stretch(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_stretch(instance);
    }

    pub fn set_stretch(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_stretch(instance, value);
    }

    pub fn get_unicodeRange(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_unicodeRange(instance);
    }

    pub fn set_unicodeRange(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_unicodeRange(instance, value);
    }

    pub fn get_featureSettings(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_featureSettings(instance);
    }

    pub fn set_featureSettings(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_featureSettings(instance, value);
    }

    pub fn get_variationSettings(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_variationSettings(instance);
    }

    pub fn set_variationSettings(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_variationSettings(instance, value);
    }

    pub fn get_display(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_display(instance);
    }

    pub fn set_display(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_display(instance, value);
    }

    pub fn get_ascentOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_ascentOverride(instance);
    }

    pub fn set_ascentOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_ascentOverride(instance, value);
    }

    pub fn get_descentOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_descentOverride(instance);
    }

    pub fn set_descentOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_descentOverride(instance, value);
    }

    pub fn get_lineGapOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try FontFaceImpl.get_lineGapOverride(instance);
    }

    pub fn set_lineGapOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try FontFaceImpl.set_lineGapOverride(instance, value);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!FontFaceLoadStatus {
        return try FontFaceImpl.get_status(instance);
    }

    pub fn get_loaded(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FontFaceImpl.get_loaded(instance);
    }

    pub fn get_features(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontFaceImpl.get_features(instance);
    }

    pub fn get_variations(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontFaceImpl.get_variations(instance);
    }

    pub fn get_palettes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontFaceImpl.get_palettes(instance);
    }

    pub fn call_load(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FontFaceImpl.call_load(instance);
    }

};

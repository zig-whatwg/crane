//! Generated from: css-fonts-5.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSFontFaceDescriptorsImpl = @import("impls").CSSFontFaceDescriptors;
const mixins = @import("mixins");
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSFontFaceDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFaceDescriptors";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleDeclaration.State;
        pub const ParentInterface = CSSStyleDeclaration;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "src", "get_src", "set_src" },
            .{ "fontFamily", "get_fontFamily", "set_fontFamily" },
            .{ "font-family", "get_font_family", "set_font_family" },
            .{ "fontStyle", "get_fontStyle", "set_fontStyle" },
            .{ "font-style", "get_font_style", "set_font_style" },
            .{ "fontWeight", "get_fontWeight", "set_fontWeight" },
            .{ "font-weight", "get_font_weight", "set_font_weight" },
            .{ "fontStretch", "get_fontStretch", "set_fontStretch" },
            .{ "font-stretch", "get_font_stretch", "set_font_stretch" },
            .{ "fontWidth", "get_fontWidth", "set_fontWidth" },
            .{ "font-width", "get_font_width", "set_font_width" },
            .{ "fontSize", "get_fontSize", "set_fontSize" },
            .{ "font-size", "get_font_size", "set_font_size" },
            .{ "sizeAdjust", "get_sizeAdjust", "set_sizeAdjust" },
            .{ "size-adjust", "get_size_adjust", "set_size_adjust" },
            .{ "unicodeRange", "get_unicodeRange", "set_unicodeRange" },
            .{ "unicode-range", "get_unicode_range", "set_unicode_range" },
            .{ "fontFeatureSettings", "get_fontFeatureSettings", "set_fontFeatureSettings" },
            .{ "font-feature-settings", "get_font_feature_settings", "set_font_feature_settings" },
            .{ "fontVariationSettings", "get_fontVariationSettings", "set_fontVariationSettings" },
            .{ "font-variation-settings", "get_font_variation_settings", "set_font_variation_settings" },
            .{ "fontNamedInstance", "get_fontNamedInstance", "set_fontNamedInstance" },
            .{ "font-named-instance", "get_font_named_instance", "set_font_named_instance" },
            .{ "fontDisplay", "get_fontDisplay", "set_fontDisplay" },
            .{ "font-display", "get_font_display", "set_font_display" },
            .{ "fontLanguageOverride", "get_fontLanguageOverride", "set_fontLanguageOverride" },
            .{ "font-language-override", "get_font_language_override", "set_font_language_override" },
            .{ "ascentOverride", "get_ascentOverride", "set_ascentOverride" },
            .{ "ascent-override", "get_ascent_override", "set_ascent_override" },
            .{ "descentOverride", "get_descentOverride", "set_descentOverride" },
            .{ "descent-override", "get_descent_override", "set_descent_override" },
            .{ "lineGapOverride", "get_lineGapOverride", "set_lineGapOverride" },
            .{ "line-gap-override", "get_line_gap_override", "set_line_gap_override" },
            .{ "superscriptPositionOverride", "get_superscriptPositionOverride", "set_superscriptPositionOverride" },
            .{ "superscript-position-override", "get_superscript_position_override", "set_superscript_position_override" },
            .{ "subscriptPositionOverride", "get_subscriptPositionOverride", "set_subscriptPositionOverride" },
            .{ "subscript-position-override", "get_subscript_position_override", "set_subscript_position_override" },
            .{ "superscriptSizeOverride", "get_superscriptSizeOverride", "set_superscriptSizeOverride" },
            .{ "superscript-size-override", "get_superscript_size_override", "set_superscript_size_override" },
            .{ "subscriptSizeOverride", "get_subscriptSizeOverride", "set_subscriptSizeOverride" },
            .{ "subscript-size-override", "get_subscript_size_override", "set_subscript_size_override" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
            "getPropertyValue",
            "getPropertyPriority",
            "setProperty",
            "removeProperty",
            "getPropertyValue",
            "getPropertyCSSValue",
            "removeProperty",
            "getPropertyPriority",
            "setProperty",
            "item",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "src", "get_src", "set_src" },
            .{ "fontFamily", "get_fontFamily", "set_fontFamily" },
            .{ "font-family", "get_font_family", "set_font_family" },
            .{ "fontStyle", "get_fontStyle", "set_fontStyle" },
            .{ "font-style", "get_font_style", "set_font_style" },
            .{ "fontWeight", "get_fontWeight", "set_fontWeight" },
            .{ "font-weight", "get_font_weight", "set_font_weight" },
            .{ "fontStretch", "get_fontStretch", "set_fontStretch" },
            .{ "font-stretch", "get_font_stretch", "set_font_stretch" },
            .{ "fontWidth", "get_fontWidth", "set_fontWidth" },
            .{ "font-width", "get_font_width", "set_font_width" },
            .{ "fontSize", "get_fontSize", "set_fontSize" },
            .{ "font-size", "get_font_size", "set_font_size" },
            .{ "sizeAdjust", "get_sizeAdjust", "set_sizeAdjust" },
            .{ "size-adjust", "get_size_adjust", "set_size_adjust" },
            .{ "unicodeRange", "get_unicodeRange", "set_unicodeRange" },
            .{ "unicode-range", "get_unicode_range", "set_unicode_range" },
            .{ "fontFeatureSettings", "get_fontFeatureSettings", "set_fontFeatureSettings" },
            .{ "font-feature-settings", "get_font_feature_settings", "set_font_feature_settings" },
            .{ "fontVariationSettings", "get_fontVariationSettings", "set_fontVariationSettings" },
            .{ "font-variation-settings", "get_font_variation_settings", "set_font_variation_settings" },
            .{ "fontNamedInstance", "get_fontNamedInstance", "set_fontNamedInstance" },
            .{ "font-named-instance", "get_font_named_instance", "set_font_named_instance" },
            .{ "fontDisplay", "get_fontDisplay", "set_fontDisplay" },
            .{ "font-display", "get_font_display", "set_font_display" },
            .{ "fontLanguageOverride", "get_fontLanguageOverride", "set_fontLanguageOverride" },
            .{ "font-language-override", "get_font_language_override", "set_font_language_override" },
            .{ "ascentOverride", "get_ascentOverride", "set_ascentOverride" },
            .{ "ascent-override", "get_ascent_override", "set_ascent_override" },
            .{ "descentOverride", "get_descentOverride", "set_descentOverride" },
            .{ "descent-override", "get_descent_override", "set_descent_override" },
            .{ "lineGapOverride", "get_lineGapOverride", "set_lineGapOverride" },
            .{ "line-gap-override", "get_line_gap_override", "set_line_gap_override" },
            .{ "superscriptPositionOverride", "get_superscriptPositionOverride", "set_superscriptPositionOverride" },
            .{ "superscript-position-override", "get_superscript_position_override", "set_superscript_position_override" },
            .{ "subscriptPositionOverride", "get_subscriptPositionOverride", "set_subscriptPositionOverride" },
            .{ "subscript-position-override", "get_subscript_position_override", "set_subscript_position_override" },
            .{ "superscriptSizeOverride", "get_superscriptSizeOverride", "set_superscriptSizeOverride" },
            .{ "superscript-size-override", "get_superscript_size_override", "set_superscript_size_override" },
            .{ "subscriptSizeOverride", "get_subscriptSizeOverride", "set_subscriptSizeOverride" },
            .{ "subscript-size-override", "get_subscript_size_override", "set_subscript_size_override" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            src: CSSOMString = undefined,
            fontFamily: CSSOMString = undefined,
            @"font-family": CSSOMString = undefined,
            fontStyle: CSSOMString = undefined,
            @"font-style": CSSOMString = undefined,
            fontWeight: CSSOMString = undefined,
            @"font-weight": CSSOMString = undefined,
            fontStretch: CSSOMString = undefined,
            @"font-stretch": CSSOMString = undefined,
            fontWidth: CSSOMString = undefined,
            @"font-width": CSSOMString = undefined,
            fontSize: CSSOMString = undefined,
            @"font-size": CSSOMString = undefined,
            sizeAdjust: CSSOMString = undefined,
            @"size-adjust": CSSOMString = undefined,
            unicodeRange: CSSOMString = undefined,
            @"unicode-range": CSSOMString = undefined,
            fontFeatureSettings: CSSOMString = undefined,
            @"font-feature-settings": CSSOMString = undefined,
            fontVariationSettings: CSSOMString = undefined,
            @"font-variation-settings": CSSOMString = undefined,
            fontNamedInstance: CSSOMString = undefined,
            @"font-named-instance": CSSOMString = undefined,
            fontDisplay: CSSOMString = undefined,
            @"font-display": CSSOMString = undefined,
            fontLanguageOverride: CSSOMString = undefined,
            @"font-language-override": CSSOMString = undefined,
            ascentOverride: CSSOMString = undefined,
            @"ascent-override": CSSOMString = undefined,
            descentOverride: CSSOMString = undefined,
            @"descent-override": CSSOMString = undefined,
            lineGapOverride: CSSOMString = undefined,
            @"line-gap-override": CSSOMString = undefined,
            superscriptPositionOverride: CSSOMString = undefined,
            @"superscript-position-override": CSSOMString = undefined,
            subscriptPositionOverride: CSSOMString = undefined,
            @"subscript-position-override": CSSOMString = undefined,
            superscriptSizeOverride: CSSOMString = undefined,
            @"superscript-size-override": CSSOMString = undefined,
            subscriptSizeOverride: CSSOMString = undefined,
            @"subscript-size-override": CSSOMString = undefined,
            _internal: ?*CSSFontFaceDescriptorsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_ascentOverride = &get_ascentOverride,
        .get_ascent_override = &get_ascent_override,
        .get_descentOverride = &get_descentOverride,
        .get_descent_override = &get_descent_override,
        .get_fontDisplay = &get_fontDisplay,
        .get_fontFamily = &get_fontFamily,
        .get_fontFeatureSettings = &get_fontFeatureSettings,
        .get_fontLanguageOverride = &get_fontLanguageOverride,
        .get_fontNamedInstance = &get_fontNamedInstance,
        .get_fontSize = &get_fontSize,
        .get_fontStretch = &get_fontStretch,
        .get_fontStyle = &get_fontStyle,
        .get_fontVariationSettings = &get_fontVariationSettings,
        .get_fontWeight = &get_fontWeight,
        .get_fontWidth = &get_fontWidth,
        .get_font_display = &get_font_display,
        .get_font_family = &get_font_family,
        .get_font_feature_settings = &get_font_feature_settings,
        .get_font_language_override = &get_font_language_override,
        .get_font_named_instance = &get_font_named_instance,
        .get_font_size = &get_font_size,
        .get_font_stretch = &get_font_stretch,
        .get_font_style = &get_font_style,
        .get_font_variation_settings = &get_font_variation_settings,
        .get_font_weight = &get_font_weight,
        .get_font_width = &get_font_width,
        .get_lineGapOverride = &get_lineGapOverride,
        .get_line_gap_override = &get_line_gap_override,
        .get_sizeAdjust = &get_sizeAdjust,
        .get_size_adjust = &get_size_adjust,
        .get_src = &get_src,
        .get_subscriptPositionOverride = &get_subscriptPositionOverride,
        .get_subscriptSizeOverride = &get_subscriptSizeOverride,
        .get_subscript_position_override = &get_subscript_position_override,
        .get_subscript_size_override = &get_subscript_size_override,
        .get_superscriptPositionOverride = &get_superscriptPositionOverride,
        .get_superscriptSizeOverride = &get_superscriptSizeOverride,
        .get_superscript_position_override = &get_superscript_position_override,
        .get_superscript_size_override = &get_superscript_size_override,
        .get_unicodeRange = &get_unicodeRange,
        .get_unicode_range = &get_unicode_range,

        .set_ascentOverride = &set_ascentOverride,
        .set_ascent_override = &set_ascent_override,
        .set_descentOverride = &set_descentOverride,
        .set_descent_override = &set_descent_override,
        .set_fontDisplay = &set_fontDisplay,
        .set_fontFamily = &set_fontFamily,
        .set_fontFeatureSettings = &set_fontFeatureSettings,
        .set_fontLanguageOverride = &set_fontLanguageOverride,
        .set_fontNamedInstance = &set_fontNamedInstance,
        .set_fontSize = &set_fontSize,
        .set_fontStretch = &set_fontStretch,
        .set_fontStyle = &set_fontStyle,
        .set_fontVariationSettings = &set_fontVariationSettings,
        .set_fontWeight = &set_fontWeight,
        .set_fontWidth = &set_fontWidth,
        .set_font_display = &set_font_display,
        .set_font_family = &set_font_family,
        .set_font_feature_settings = &set_font_feature_settings,
        .set_font_language_override = &set_font_language_override,
        .set_font_named_instance = &set_font_named_instance,
        .set_font_size = &set_font_size,
        .set_font_stretch = &set_font_stretch,
        .set_font_style = &set_font_style,
        .set_font_variation_settings = &set_font_variation_settings,
        .set_font_weight = &set_font_weight,
        .set_font_width = &set_font_width,
        .set_lineGapOverride = &set_lineGapOverride,
        .set_line_gap_override = &set_line_gap_override,
        .set_sizeAdjust = &set_sizeAdjust,
        .set_size_adjust = &set_size_adjust,
        .set_src = &set_src,
        .set_subscriptPositionOverride = &set_subscriptPositionOverride,
        .set_subscriptSizeOverride = &set_subscriptSizeOverride,
        .set_subscript_position_override = &set_subscript_position_override,
        .set_subscript_size_override = &set_subscript_size_override,
        .set_superscriptPositionOverride = &set_superscriptPositionOverride,
        .set_superscriptSizeOverride = &set_superscriptSizeOverride,
        .set_superscript_position_override = &set_superscript_position_override,
        .set_superscript_size_override = &set_superscript_size_override,
        .set_unicodeRange = &set_unicodeRange,
        .set_unicode_range = &set_unicode_range,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSFontFaceDescriptorsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFontFaceDescriptorsImpl.deinit(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_src(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_src(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_src(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_src(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontFamily(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontFamily(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontFamily(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontFamily(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_family(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_family(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_family(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_family(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontStyle(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontStyle(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontStyle(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontStyle(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_style(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_style(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_style(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_style(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontWeight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontWeight(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontWeight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontWeight(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_weight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_weight(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_weight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_weight(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontStretch(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontStretch(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontStretch(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontStretch(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_stretch(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_stretch(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_stretch(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_stretch(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontWidth(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontWidth(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontWidth(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontWidth(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_width(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_width(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_width(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_width(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontSize(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontSize(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontSize(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontSize(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_size(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_size(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_sizeAdjust(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_sizeAdjust(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_sizeAdjust(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_sizeAdjust(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_size_adjust(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_size_adjust(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_size_adjust(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_size_adjust(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_unicodeRange(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_unicodeRange(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_unicodeRange(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_unicodeRange(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_unicode_range(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_unicode_range(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_unicode_range(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_unicode_range(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontFeatureSettings(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontFeatureSettings(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontFeatureSettings(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontFeatureSettings(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_feature_settings(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_feature_settings(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_feature_settings(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_feature_settings(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontVariationSettings(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontVariationSettings(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontVariationSettings(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontVariationSettings(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_variation_settings(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_variation_settings(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_variation_settings(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_variation_settings(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontNamedInstance(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontNamedInstance(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontNamedInstance(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontNamedInstance(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_named_instance(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_named_instance(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_named_instance(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_named_instance(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontDisplay(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontDisplay(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontDisplay(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontDisplay(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_display(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_display(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_display(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_display(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontLanguageOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_fontLanguageOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontLanguageOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_fontLanguageOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font_language_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_font_language_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font_language_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_font_language_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_ascentOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_ascentOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_ascentOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_ascentOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_ascent_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_ascent_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_ascent_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_ascent_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_descentOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_descentOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_descentOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_descentOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_descent_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_descent_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_descent_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_descent_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_lineGapOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_lineGapOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_lineGapOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_lineGapOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_line_gap_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_line_gap_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_line_gap_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_line_gap_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscriptPositionOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_superscriptPositionOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscriptPositionOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_superscriptPositionOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscript_position_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_superscript_position_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscript_position_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_superscript_position_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscriptPositionOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_subscriptPositionOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscriptPositionOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_subscriptPositionOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscript_position_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_subscript_position_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscript_position_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_subscript_position_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscriptSizeOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_superscriptSizeOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscriptSizeOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_superscriptSizeOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscript_size_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_superscript_size_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscript_size_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_superscript_size_override(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscriptSizeOverride(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_subscriptSizeOverride(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscriptSizeOverride(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_subscriptSizeOverride(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscript_size_override(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFaceDescriptorsImpl.get_subscript_size_override(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscript_size_override(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFaceDescriptorsImpl.set_subscript_size_override(instance, value);
    }

};

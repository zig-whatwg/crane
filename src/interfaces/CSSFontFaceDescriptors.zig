//! Generated from: css-fonts-5.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFontFaceDescriptorsImpl = @import("../impls/CSSFontFaceDescriptors.zig");
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig");

pub const CSSFontFaceDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFaceDescriptors";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleDeclaration;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            src: CSSOMString = undefined,
            fontFamily: CSSOMString = undefined,
            font-family: CSSOMString = undefined,
            fontStyle: CSSOMString = undefined,
            font-style: CSSOMString = undefined,
            fontWeight: CSSOMString = undefined,
            font-weight: CSSOMString = undefined,
            fontStretch: CSSOMString = undefined,
            font-stretch: CSSOMString = undefined,
            fontWidth: CSSOMString = undefined,
            font-width: CSSOMString = undefined,
            fontSize: CSSOMString = undefined,
            font-size: CSSOMString = undefined,
            sizeAdjust: CSSOMString = undefined,
            size-adjust: CSSOMString = undefined,
            unicodeRange: CSSOMString = undefined,
            unicode-range: CSSOMString = undefined,
            fontFeatureSettings: CSSOMString = undefined,
            font-feature-settings: CSSOMString = undefined,
            fontVariationSettings: CSSOMString = undefined,
            font-variation-settings: CSSOMString = undefined,
            fontNamedInstance: CSSOMString = undefined,
            font-named-instance: CSSOMString = undefined,
            fontDisplay: CSSOMString = undefined,
            font-display: CSSOMString = undefined,
            fontLanguageOverride: CSSOMString = undefined,
            font-language-override: CSSOMString = undefined,
            ascentOverride: CSSOMString = undefined,
            ascent-override: CSSOMString = undefined,
            descentOverride: CSSOMString = undefined,
            descent-override: CSSOMString = undefined,
            lineGapOverride: CSSOMString = undefined,
            line-gap-override: CSSOMString = undefined,
            superscriptPositionOverride: CSSOMString = undefined,
            superscript-position-override: CSSOMString = undefined,
            subscriptPositionOverride: CSSOMString = undefined,
            subscript-position-override: CSSOMString = undefined,
            superscriptSizeOverride: CSSOMString = undefined,
            superscript-size-override: CSSOMString = undefined,
            subscriptSizeOverride: CSSOMString = undefined,
            subscript-size-override: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSFontFaceDescriptors, .{
        .deinit_fn = &deinit_wrapper,

        .get_ascent-override = &get_ascent-override,
        .get_ascentOverride = &get_ascentOverride,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_descent-override = &get_descent-override,
        .get_descentOverride = &get_descentOverride,
        .get_font-display = &get_font-display,
        .get_font-family = &get_font-family,
        .get_font-feature-settings = &get_font-feature-settings,
        .get_font-language-override = &get_font-language-override,
        .get_font-named-instance = &get_font-named-instance,
        .get_font-size = &get_font-size,
        .get_font-stretch = &get_font-stretch,
        .get_font-style = &get_font-style,
        .get_font-variation-settings = &get_font-variation-settings,
        .get_font-weight = &get_font-weight,
        .get_font-width = &get_font-width,
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
        .get_length = &get_length,
        .get_length = &get_length,
        .get_line-gap-override = &get_line-gap-override,
        .get_lineGapOverride = &get_lineGapOverride,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_size-adjust = &get_size-adjust,
        .get_sizeAdjust = &get_sizeAdjust,
        .get_src = &get_src,
        .get_subscript-position-override = &get_subscript-position-override,
        .get_subscript-size-override = &get_subscript-size-override,
        .get_subscriptPositionOverride = &get_subscriptPositionOverride,
        .get_subscriptSizeOverride = &get_subscriptSizeOverride,
        .get_superscript-position-override = &get_superscript-position-override,
        .get_superscript-size-override = &get_superscript-size-override,
        .get_superscriptPositionOverride = &get_superscriptPositionOverride,
        .get_superscriptSizeOverride = &get_superscriptSizeOverride,
        .get_unicode-range = &get_unicode-range,
        .get_unicodeRange = &get_unicodeRange,

        .set_ascent-override = &set_ascent-override,
        .set_ascentOverride = &set_ascentOverride,
        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
        .set_descent-override = &set_descent-override,
        .set_descentOverride = &set_descentOverride,
        .set_font-display = &set_font-display,
        .set_font-family = &set_font-family,
        .set_font-feature-settings = &set_font-feature-settings,
        .set_font-language-override = &set_font-language-override,
        .set_font-named-instance = &set_font-named-instance,
        .set_font-size = &set_font-size,
        .set_font-stretch = &set_font-stretch,
        .set_font-style = &set_font-style,
        .set_font-variation-settings = &set_font-variation-settings,
        .set_font-weight = &set_font-weight,
        .set_font-width = &set_font-width,
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
        .set_line-gap-override = &set_line-gap-override,
        .set_lineGapOverride = &set_lineGapOverride,
        .set_size-adjust = &set_size-adjust,
        .set_sizeAdjust = &set_sizeAdjust,
        .set_src = &set_src,
        .set_subscript-position-override = &set_subscript-position-override,
        .set_subscript-size-override = &set_subscript-size-override,
        .set_subscriptPositionOverride = &set_subscriptPositionOverride,
        .set_subscriptSizeOverride = &set_subscriptSizeOverride,
        .set_superscript-position-override = &set_superscript-position-override,
        .set_superscript-size-override = &set_superscript-size-override,
        .set_superscriptPositionOverride = &set_superscriptPositionOverride,
        .set_superscriptSizeOverride = &set_superscriptSizeOverride,
        .set_unicode-range = &set_unicode-range,
        .set_unicodeRange = &set_unicodeRange,

        .call_getPropertyCSSValue = &call_getPropertyCSSValue,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,
        .call_setProperty = &call_setProperty,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSFontFaceDescriptorsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_cssText(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        CSSFontFaceDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_parentRule(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_parentRule(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_src(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_src(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_src(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_src(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontFamily(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontFamily(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontFamily(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontFamily(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-family(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-family(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-family(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-family(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontStyle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontStyle(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontStyle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontStyle(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-style(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-style(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-style(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-style(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontWeight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontWeight(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontWeight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontWeight(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-weight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-weight(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-weight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-weight(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontStretch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontStretch(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontStretch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontStretch(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-stretch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-stretch(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-stretch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-stretch(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontWidth(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontWidth(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontWidth(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontWidth(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-width(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-width(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-width(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-width(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontSize(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontSize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontSize(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-size(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-size(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_sizeAdjust(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_sizeAdjust(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_sizeAdjust(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_sizeAdjust(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_size-adjust(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_size-adjust(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_size-adjust(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_size-adjust(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_unicodeRange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_unicodeRange(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_unicodeRange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_unicodeRange(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_unicode-range(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_unicode-range(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_unicode-range(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_unicode-range(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontFeatureSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontFeatureSettings(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontFeatureSettings(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontFeatureSettings(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-feature-settings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-feature-settings(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-feature-settings(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-feature-settings(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontVariationSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontVariationSettings(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontVariationSettings(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontVariationSettings(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-variation-settings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-variation-settings(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-variation-settings(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-variation-settings(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontNamedInstance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontNamedInstance(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontNamedInstance(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontNamedInstance(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-named-instance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-named-instance(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-named-instance(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-named-instance(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontDisplay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontDisplay(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontDisplay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontDisplay(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-display(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-display(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-display(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-display(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_fontLanguageOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_fontLanguageOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_fontLanguageOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_fontLanguageOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_font-language-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_font-language-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_font-language-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_font-language-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_ascentOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_ascentOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_ascentOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_ascentOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_ascent-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_ascent-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_ascent-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_ascent-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_descentOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_descentOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_descentOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_descentOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_descent-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_descent-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_descent-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_descent-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_lineGapOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_lineGapOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_lineGapOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_lineGapOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_line-gap-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_line-gap-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_line-gap-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_line-gap-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscriptPositionOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_superscriptPositionOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscriptPositionOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_superscriptPositionOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscript-position-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_superscript-position-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscript-position-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_superscript-position-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscriptPositionOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_subscriptPositionOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscriptPositionOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_subscriptPositionOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscript-position-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_subscript-position-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscript-position-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_subscript-position-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscriptSizeOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_superscriptSizeOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscriptSizeOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_superscriptSizeOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_superscript-size-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_superscript-size-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_superscript-size-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_superscript-size-override(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscriptSizeOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_subscriptSizeOverride(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscriptSizeOverride(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_subscriptSizeOverride(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_subscript-size-override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFaceDescriptorsImpl.get_subscript-size-override(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_subscript-size-override(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFaceDescriptorsImpl.set_subscript-size-override(state, value);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return CSSFontFaceDescriptorsImpl.long(state, arg),
            .long => |arg| return CSSFontFaceDescriptorsImpl.long(state, arg),
        }
    }

    /// Arguments for removeProperty (WebIDL overloading)
    pub const RemovePropertyArgs = union(enum) {
        /// removeProperty(property)
        CSSOMString: anyopaque,
        /// removeProperty(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_removeProperty(instance: *runtime.Instance, args: RemovePropertyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSFontFaceDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSFontFaceDescriptorsImpl.string(state, arg),
        }
    }

    /// Arguments for getPropertyPriority (WebIDL overloading)
    pub const GetPropertyPriorityArgs = union(enum) {
        /// getPropertyPriority(property)
        CSSOMString: anyopaque,
        /// getPropertyPriority(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_getPropertyPriority(instance: *runtime.Instance, args: GetPropertyPriorityArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSFontFaceDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSFontFaceDescriptorsImpl.string(state, arg),
        }
    }

    /// Arguments for setProperty (WebIDL overloading)
    pub const SetPropertyArgs = union(enum) {
        /// setProperty(property, value, priority)
        CSSOMString_CSSOMString_CSSOMString: struct {
            property: anyopaque,
            value: anyopaque,
            priority: anyopaque,
        },
        /// setProperty(propertyName, value, priority)
        string_string_string: struct {
            propertyName: runtime.DOMString,
            value: runtime.DOMString,
            priority: runtime.DOMString,
        },
    };

    pub fn call_setProperty(instance: *runtime.Instance, args: SetPropertyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString_CSSOMString_CSSOMString => |a| return CSSFontFaceDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(state, a.property, a.value, a.priority),
            .string_string_string => |a| return CSSFontFaceDescriptorsImpl.string_string_string(state, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSFontFaceDescriptorsImpl.call_getPropertyCSSValue(state, propertyName);
    }

    /// Arguments for getPropertyValue (WebIDL overloading)
    pub const GetPropertyValueArgs = union(enum) {
        /// getPropertyValue(property)
        CSSOMString: anyopaque,
        /// getPropertyValue(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_getPropertyValue(instance: *runtime.Instance, args: GetPropertyValueArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSFontFaceDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSFontFaceDescriptorsImpl.string(state, arg),
        }
    }

};

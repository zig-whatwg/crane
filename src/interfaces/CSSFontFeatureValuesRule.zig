//! Generated from: css-fonts.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFontFeatureValuesRuleImpl = @import("../impls/CSSFontFeatureValuesRule.zig");
const CSSRule = @import("CSSRule.zig");

pub const CSSFontFeatureValuesRule = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFeatureValuesRule";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSRule;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            fontFamily: CSSOMString = undefined,
            annotation: CSSFontFeatureValuesMap = undefined,
            ornaments: CSSFontFeatureValuesMap = undefined,
            stylistic: CSSFontFeatureValuesMap = undefined,
            swash: CSSFontFeatureValuesMap = undefined,
            characterVariant: CSSFontFeatureValuesMap = undefined,
            styleset: CSSFontFeatureValuesMap = undefined,
            historicalForms: CSSFontFeatureValuesMap = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSFontFeatureValuesRule, .{
        .deinit_fn = &deinit_wrapper,

        .get_CHARSET_RULE = &CSSRule.get_CHARSET_RULE,
        .get_CHARSET_RULE = &CSSRule.get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &CSSRule.get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &CSSRule.get_FONT_FACE_RULE,
        .get_FONT_FACE_RULE = &CSSRule.get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &CSSRule.get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &CSSRule.get_IMPORT_RULE,
        .get_IMPORT_RULE = &CSSRule.get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &CSSRule.get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &CSSRule.get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &CSSRule.get_MARGIN_RULE,
        .get_MEDIA_RULE = &CSSRule.get_MEDIA_RULE,
        .get_MEDIA_RULE = &CSSRule.get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &CSSRule.get_NAMESPACE_RULE,
        .get_PAGE_RULE = &CSSRule.get_PAGE_RULE,
        .get_PAGE_RULE = &CSSRule.get_PAGE_RULE,
        .get_STYLE_RULE = &CSSRule.get_STYLE_RULE,
        .get_STYLE_RULE = &CSSRule.get_STYLE_RULE,
        .get_SUPPORTS_RULE = &CSSRule.get_SUPPORTS_RULE,
        .get_UNKNOWN_RULE = &CSSRule.get_UNKNOWN_RULE,
        .get_annotation = &get_annotation,
        .get_characterVariant = &get_characterVariant,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_fontFamily = &get_fontFamily,
        .get_historicalForms = &get_historicalForms,
        .get_ornaments = &get_ornaments,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_styleset = &get_styleset,
        .get_stylistic = &get_stylistic,
        .get_swash = &get_swash,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
        .set_fontFamily = &set_fontFamily,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSFontFeatureValuesRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSFontFeatureValuesRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFeatureValuesRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_parentRule(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_type(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_type(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSFontFeatureValuesRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_parentRule(state);
    }

    pub fn get_fontFamily(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_fontFamily(state);
    }

    pub fn set_fontFamily(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFontFeatureValuesRuleImpl.set_fontFamily(state, value);
    }

    pub fn get_annotation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_annotation(state);
    }

    pub fn get_ornaments(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_ornaments(state);
    }

    pub fn get_stylistic(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_stylistic(state);
    }

    pub fn get_swash(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_swash(state);
    }

    pub fn get_characterVariant(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_characterVariant(state);
    }

    pub fn get_styleset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_styleset(state);
    }

    pub fn get_historicalForms(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFontFeatureValuesRuleImpl.get_historicalForms(state);
    }

};

//! Generated from: css-counter-styles.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSCounterStyleRuleImpl = @import("impls").CSSCounterStyleRule;
const CSSRule = @import("interfaces").CSSRule;
const CSSOMString = @import("interfaces").CSSOMString;

pub const CSSCounterStyleRule = struct {
    pub const Meta = struct {
        pub const name = "CSSCounterStyleRule";
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
            name: CSSOMString = undefined,
            system: CSSOMString = undefined,
            symbols: CSSOMString = undefined,
            additiveSymbols: CSSOMString = undefined,
            negative: CSSOMString = undefined,
            prefix: CSSOMString = undefined,
            suffix: CSSOMString = undefined,
            range: CSSOMString = undefined,
            pad: CSSOMString = undefined,
            speakAs: CSSOMString = undefined,
            fallback: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSCounterStyleRule, .{
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
        .get_additiveSymbols = &get_additiveSymbols,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_fallback = &get_fallback,
        .get_name = &get_name,
        .get_negative = &get_negative,
        .get_pad = &get_pad,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_prefix = &get_prefix,
        .get_range = &get_range,
        .get_speakAs = &get_speakAs,
        .get_suffix = &get_suffix,
        .get_symbols = &get_symbols,
        .get_system = &get_system,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_additiveSymbols = &set_additiveSymbols,
        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
        .set_fallback = &set_fallback,
        .set_name = &set_name,
        .set_negative = &set_negative,
        .set_pad = &set_pad,
        .set_prefix = &set_prefix,
        .set_range = &set_range,
        .set_speakAs = &set_speakAs,
        .set_suffix = &set_suffix,
        .set_symbols = &set_symbols,
        .set_system = &set_system,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSCounterStyleRuleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSCounterStyleRuleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_parentRule(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSCounterStyleRuleImpl.get_type(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSCounterStyleRuleImpl.get_type(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSCounterStyleRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSCounterStyleRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!CSSStyleSheet {
        return try CSSCounterStyleRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSCounterStyleRuleImpl.get_parentRule(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_name(instance, value);
    }

    pub fn get_system(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_system(instance);
    }

    pub fn set_system(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_system(instance, value);
    }

    pub fn get_symbols(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_symbols(instance);
    }

    pub fn set_symbols(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_symbols(instance, value);
    }

    pub fn get_additiveSymbols(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_additiveSymbols(instance);
    }

    pub fn set_additiveSymbols(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_additiveSymbols(instance, value);
    }

    pub fn get_negative(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_negative(instance);
    }

    pub fn set_negative(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_negative(instance, value);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_prefix(instance);
    }

    pub fn set_prefix(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_prefix(instance, value);
    }

    pub fn get_suffix(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_suffix(instance);
    }

    pub fn set_suffix(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_suffix(instance, value);
    }

    pub fn get_range(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_range(instance);
    }

    pub fn set_range(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_range(instance, value);
    }

    pub fn get_pad(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_pad(instance);
    }

    pub fn set_pad(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_pad(instance, value);
    }

    pub fn get_speakAs(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_speakAs(instance);
    }

    pub fn set_speakAs(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_speakAs(instance, value);
    }

    pub fn get_fallback(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSCounterStyleRuleImpl.get_fallback(instance);
    }

    pub fn set_fallback(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSCounterStyleRuleImpl.set_fallback(instance, value);
    }

};

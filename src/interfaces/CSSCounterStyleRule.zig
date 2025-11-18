//! Generated from: css-counter-styles.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSCounterStyleRuleImpl = @import("../impls/CSSCounterStyleRule.zig");
const CSSRule = @import("CSSRule.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CSSCounterStyleRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_parentRule(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_type(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_type(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_parentRule(state);
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_name(state);
    }

    pub fn set_name(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_name(state, value);
    }

    pub fn get_system(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_system(state);
    }

    pub fn set_system(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_system(state, value);
    }

    pub fn get_symbols(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_symbols(state);
    }

    pub fn set_symbols(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_symbols(state, value);
    }

    pub fn get_additiveSymbols(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_additiveSymbols(state);
    }

    pub fn set_additiveSymbols(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_additiveSymbols(state, value);
    }

    pub fn get_negative(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_negative(state);
    }

    pub fn set_negative(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_negative(state, value);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_prefix(state);
    }

    pub fn set_prefix(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_prefix(state, value);
    }

    pub fn get_suffix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_suffix(state);
    }

    pub fn set_suffix(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_suffix(state, value);
    }

    pub fn get_range(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_range(state);
    }

    pub fn set_range(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_range(state, value);
    }

    pub fn get_pad(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_pad(state);
    }

    pub fn set_pad(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_pad(state, value);
    }

    pub fn get_speakAs(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_speakAs(state);
    }

    pub fn set_speakAs(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_speakAs(state, value);
    }

    pub fn get_fallback(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSCounterStyleRuleImpl.get_fallback(state);
    }

    pub fn set_fallback(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSCounterStyleRuleImpl.set_fallback(state, value);
    }

};

//! Generated from: css-conditional.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSupportsRuleImpl = @import("impls").CSSSupportsRule;
const CSSConditionRule = @import("interfaces").CSSConditionRule;

pub const CSSSupportsRule = struct {
    pub const Meta = struct {
        pub const name = "CSSSupportsRule";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSConditionRule;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            matches: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSSupportsRule, .{
        .deinit_fn = &deinit_wrapper,

        .get_CHARSET_RULE = &CSSConditionRule.get_CHARSET_RULE,
        .get_CHARSET_RULE = &CSSConditionRule.get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &CSSConditionRule.get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &CSSConditionRule.get_FONT_FACE_RULE,
        .get_FONT_FACE_RULE = &CSSConditionRule.get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &CSSConditionRule.get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &CSSConditionRule.get_IMPORT_RULE,
        .get_IMPORT_RULE = &CSSConditionRule.get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &CSSConditionRule.get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &CSSConditionRule.get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &CSSConditionRule.get_MARGIN_RULE,
        .get_MEDIA_RULE = &CSSConditionRule.get_MEDIA_RULE,
        .get_MEDIA_RULE = &CSSConditionRule.get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &CSSConditionRule.get_NAMESPACE_RULE,
        .get_PAGE_RULE = &CSSConditionRule.get_PAGE_RULE,
        .get_PAGE_RULE = &CSSConditionRule.get_PAGE_RULE,
        .get_STYLE_RULE = &CSSConditionRule.get_STYLE_RULE,
        .get_STYLE_RULE = &CSSConditionRule.get_STYLE_RULE,
        .get_SUPPORTS_RULE = &CSSConditionRule.get_SUPPORTS_RULE,
        .get_UNKNOWN_RULE = &CSSConditionRule.get_UNKNOWN_RULE,
        .get_conditionText = &get_conditionText,
        .get_cssRules = &get_cssRules,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_matches = &get_matches,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,

        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSSupportsRuleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSupportsRuleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSSupportsRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSSupportsRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSSupportsRuleImpl.get_parentRule(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSSupportsRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSSupportsRuleImpl.get_type(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSSupportsRuleImpl.get_type(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSSupportsRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSSupportsRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!CSSStyleSheet {
        return try CSSSupportsRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSSupportsRuleImpl.get_parentRule(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyerror!CSSRuleList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cssRules) |cached| {
            return cached;
        }
        const value = try CSSSupportsRuleImpl.get_cssRules(instance);
        state.cached_cssRules = value;
        return value;
    }

    pub fn get_conditionText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSSupportsRuleImpl.get_conditionText(instance);
    }

    pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
        return try CSSSupportsRuleImpl.get_matches(instance);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try CSSSupportsRuleImpl.call_deleteRule(instance, index);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: anyopaque, index: u32) anyerror!u32 {
        
        return try CSSSupportsRuleImpl.call_insertRule(instance, rule, index);
    }

};

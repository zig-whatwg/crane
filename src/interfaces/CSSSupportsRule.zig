//! Generated from: css-conditional.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSupportsRuleImpl = @import("../impls/CSSSupportsRule.zig");
const CSSConditionRule = @import("CSSConditionRule.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CSSSupportsRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSSupportsRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSSupportsRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_parentRule(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_type(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_type(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSSupportsRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_parentRule(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cssRules) |cached| {
            return cached;
        }
        const value = CSSSupportsRuleImpl.get_cssRules(state);
        state.cached_cssRules = value;
        return value;
    }

    pub fn get_conditionText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_conditionText(state);
    }

    pub fn get_matches(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSSupportsRuleImpl.get_matches(state);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return CSSSupportsRuleImpl.call_deleteRule(state, index);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: anyopaque, index: u32) u32 {
        const state = instance.getState(State);
        
        return CSSSupportsRuleImpl.call_insertRule(state, rule, index);
    }

};

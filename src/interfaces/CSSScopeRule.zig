//! Generated from: css-cascade-6.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSScopeRuleImpl = @import("../impls/CSSScopeRule.zig");
const CSSGroupingRule = @import("CSSGroupingRule.zig");

pub const CSSScopeRule = struct {
    pub const Meta = struct {
        pub const name = "CSSScopeRule";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSGroupingRule;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            start: ?CSSOMString = null,
            end: ?CSSOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSScopeRule, .{
        .deinit_fn = &deinit_wrapper,

        .get_CHARSET_RULE = &CSSGroupingRule.get_CHARSET_RULE,
        .get_CHARSET_RULE = &CSSGroupingRule.get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &CSSGroupingRule.get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &CSSGroupingRule.get_FONT_FACE_RULE,
        .get_FONT_FACE_RULE = &CSSGroupingRule.get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &CSSGroupingRule.get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &CSSGroupingRule.get_IMPORT_RULE,
        .get_IMPORT_RULE = &CSSGroupingRule.get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &CSSGroupingRule.get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &CSSGroupingRule.get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &CSSGroupingRule.get_MARGIN_RULE,
        .get_MEDIA_RULE = &CSSGroupingRule.get_MEDIA_RULE,
        .get_MEDIA_RULE = &CSSGroupingRule.get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &CSSGroupingRule.get_NAMESPACE_RULE,
        .get_PAGE_RULE = &CSSGroupingRule.get_PAGE_RULE,
        .get_PAGE_RULE = &CSSGroupingRule.get_PAGE_RULE,
        .get_STYLE_RULE = &CSSGroupingRule.get_STYLE_RULE,
        .get_STYLE_RULE = &CSSGroupingRule.get_STYLE_RULE,
        .get_SUPPORTS_RULE = &CSSGroupingRule.get_SUPPORTS_RULE,
        .get_UNKNOWN_RULE = &CSSGroupingRule.get_UNKNOWN_RULE,
        .get_cssRules = &get_cssRules,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_end = &get_end,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_start = &get_start,
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
        CSSScopeRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSScopeRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSScopeRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_parentRule(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_type(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_type(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSScopeRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_parentRule(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cssRules) |cached| {
            return cached;
        }
        const value = CSSScopeRuleImpl.get_cssRules(state);
        state.cached_cssRules = value;
        return value;
    }

    pub fn get_start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_start(state);
    }

    pub fn get_end(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSScopeRuleImpl.get_end(state);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return CSSScopeRuleImpl.call_deleteRule(state, index);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: anyopaque, index: u32) u32 {
        const state = instance.getState(State);
        
        return CSSScopeRuleImpl.call_insertRule(state, rule, index);
    }

};

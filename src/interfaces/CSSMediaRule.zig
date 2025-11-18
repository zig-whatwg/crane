//! Generated from: css-conditional.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSMediaRuleImpl = @import("../impls/CSSMediaRule.zig");
const CSSConditionRule = @import("CSSConditionRule.zig");

pub const CSSMediaRule = struct {
    pub const Meta = struct {
        pub const name = "CSSMediaRule";
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
            media: MediaList = undefined,
            matches: bool = undefined,
            media: stylesheets::MediaList = undefined,
            cssRules: CSSRuleList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSMediaRule, .{
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
        .get_cssRules = &get_cssRules,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_matches = &get_matches,
        .get_media = &get_media,
        .get_media = &get_media,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,

        .call_deleteRule = &call_deleteRule,
        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
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
        CSSMediaRuleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSMediaRuleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSMediaRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_parentRule(state);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_type(state);
    }

    pub fn get_type(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_type(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSMediaRuleImpl.set_cssText(state, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_parentStyleSheet(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_parentRule(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_cssRules) |cached| {
            return cached;
        }
        const value = CSSMediaRuleImpl.get_cssRules(state);
        state.cached_cssRules = value;
        return value;
    }

    pub fn get_conditionText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_conditionText(state);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_media) |cached| {
            return cached;
        }
        const value = CSSMediaRuleImpl.get_media(state);
        state.cached_media = value;
        return value;
    }

    pub fn get_matches(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_matches(state);
    }

    pub fn get_media(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_media(state);
    }

    pub fn get_cssRules(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSMediaRuleImpl.get_cssRules(state);
    }

    /// Arguments for deleteRule (WebIDL overloading)
    pub const DeleteRuleArgs = union(enum) {
        /// deleteRule(index)
        long: u32,
        /// deleteRule(index)
        long: u32,
    };

    pub fn call_deleteRule(instance: *runtime.Instance, args: DeleteRuleArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return CSSMediaRuleImpl.long(state, arg),
            .long => |arg| return CSSMediaRuleImpl.long(state, arg),
        }
    }

    /// Arguments for insertRule (WebIDL overloading)
    pub const InsertRuleArgs = union(enum) {
        /// insertRule(rule, index)
        CSSOMString_long: struct {
            rule: anyopaque,
            index: u32,
        },
        /// insertRule(rule, index)
        string_long: struct {
            rule: runtime.DOMString,
            index: u32,
        },
    };

    pub fn call_insertRule(instance: *runtime.Instance, args: InsertRuleArgs) u32 {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString_long => |a| return CSSMediaRuleImpl.CSSOMString_long(state, a.rule, a.index),
            .string_long => |a| return CSSMediaRuleImpl.string_long(state, a.rule, a.index),
        }
    }

};

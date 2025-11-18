//! Generated from: css-nesting.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSNestedDeclarationsImpl = @import("impls").CSSNestedDeclarations;
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;

pub const CSSNestedDeclarations = struct {
    pub const Meta = struct {
        pub const name = "CSSNestedDeclarations";
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
            style: CSSStyleProperties = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSNestedDeclarations, .{
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
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_style = &get_style,
        .get_type = &get_type,
        .get_type = &get_type,

        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSNestedDeclarationsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSNestedDeclarationsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSNestedDeclarationsImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSNestedDeclarationsImpl.set_cssText(instance, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSNestedDeclarationsImpl.get_parentRule(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSNestedDeclarationsImpl.get_parentStyleSheet(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSNestedDeclarationsImpl.get_type(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSNestedDeclarationsImpl.get_type(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSNestedDeclarationsImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSNestedDeclarationsImpl.set_cssText(instance, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!CSSStyleSheet {
        return try CSSNestedDeclarationsImpl.get_parentStyleSheet(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSNestedDeclarationsImpl.get_parentRule(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=cssText]
    pub fn get_style(instance: *runtime.Instance) anyerror!CSSStyleProperties {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_style) |cached| {
            return cached;
        }
        const value = try CSSNestedDeclarationsImpl.get_style(instance);
        state.cached_style = value;
        return value;
    }

};

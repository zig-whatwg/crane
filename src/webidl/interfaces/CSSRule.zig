//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSRuleImpl = @import("impls").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("interfaces").CSSOMString;

pub const CSSRule = struct {
    pub const Meta = struct {
        pub const name = "CSSRule";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            cssText: CSSOMString = undefined,
            parentRule: ?CSSRule = null,
            parentStyleSheet: ?CSSStyleSheet = null,
            type: u16 = undefined,
            type: u16 = undefined,
            cssText: runtime.DOMString = undefined,
            parentStyleSheet: CSSStyleSheet = undefined,
            parentRule: CSSRule = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short STYLE_RULE = 1;
    pub fn get_STYLE_RULE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CHARSET_RULE = 2;
    pub fn get_CHARSET_RULE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short IMPORT_RULE = 3;
    pub fn get_IMPORT_RULE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short MEDIA_RULE = 4;
    pub fn get_MEDIA_RULE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short FONT_FACE_RULE = 5;
    pub fn get_FONT_FACE_RULE() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short PAGE_RULE = 6;
    pub fn get_PAGE_RULE() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short MARGIN_RULE = 9;
    pub fn get_MARGIN_RULE() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short NAMESPACE_RULE = 10;
    pub fn get_NAMESPACE_RULE() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short UNKNOWN_RULE = 0;
    pub fn get_UNKNOWN_RULE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short STYLE_RULE = 1;
    pub fn get_STYLE_RULE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CHARSET_RULE = 2;
    pub fn get_CHARSET_RULE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short IMPORT_RULE = 3;
    pub fn get_IMPORT_RULE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short MEDIA_RULE = 4;
    pub fn get_MEDIA_RULE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short FONT_FACE_RULE = 5;
    pub fn get_FONT_FACE_RULE() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short PAGE_RULE = 6;
    pub fn get_PAGE_RULE() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short SUPPORTS_RULE = 12;
    pub fn get_SUPPORTS_RULE() u16 {
        return 12;
    }

    /// WebIDL constant: const unsigned short KEYFRAMES_RULE = 7;
    pub fn get_KEYFRAMES_RULE() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short KEYFRAME_RULE = 8;
    pub fn get_KEYFRAME_RULE() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short COUNTER_STYLE_RULE = 11;
    pub fn get_COUNTER_STYLE_RULE() u16 {
        return 11;
    }

    /// WebIDL constant: const unsigned short FONT_FEATURE_VALUES_RULE = 14;
    pub fn get_FONT_FEATURE_VALUES_RULE() u16 {
        return 14;
    }

    pub const vtable = runtime.buildVTable(CSSRule, .{
        .deinit_fn = &deinit_wrapper,

        .get_CHARSET_RULE = &get_CHARSET_RULE,
        .get_CHARSET_RULE = &get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &get_FONT_FACE_RULE,
        .get_FONT_FACE_RULE = &get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &get_IMPORT_RULE,
        .get_IMPORT_RULE = &get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &get_MARGIN_RULE,
        .get_MEDIA_RULE = &get_MEDIA_RULE,
        .get_MEDIA_RULE = &get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &get_NAMESPACE_RULE,
        .get_PAGE_RULE = &get_PAGE_RULE,
        .get_PAGE_RULE = &get_PAGE_RULE,
        .get_STYLE_RULE = &get_STYLE_RULE,
        .get_STYLE_RULE = &get_STYLE_RULE,
        .get_SUPPORTS_RULE = &get_SUPPORTS_RULE,
        .get_UNKNOWN_RULE = &get_UNKNOWN_RULE,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_parentStyleSheet = &get_parentStyleSheet,
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
        CSSRuleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSRuleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSRuleImpl.get_parentRule(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSRuleImpl.get_type(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSRuleImpl.get_type(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!CSSStyleSheet {
        return try CSSRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSRuleImpl.get_parentRule(instance);
    }

};

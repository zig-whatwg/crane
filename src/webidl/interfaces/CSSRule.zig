//! Generated from: cssom.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSRuleImpl = @import("impls").CSSRule;
const mixins = @import("mixins");
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const CSSRule = struct {
    pub const Meta = struct {
        pub const name = "CSSRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "parentRule", "get_parentRule", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "type", "get_type", null },
            .{ "type", "get_type", null },
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "parentRule", "get_parentRule", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "STYLE_RULE", "get_STYLE_RULE" },
            .{ "CHARSET_RULE", "get_CHARSET_RULE" },
            .{ "IMPORT_RULE", "get_IMPORT_RULE" },
            .{ "MEDIA_RULE", "get_MEDIA_RULE" },
            .{ "FONT_FACE_RULE", "get_FONT_FACE_RULE" },
            .{ "PAGE_RULE", "get_PAGE_RULE" },
            .{ "MARGIN_RULE", "get_MARGIN_RULE" },
            .{ "NAMESPACE_RULE", "get_NAMESPACE_RULE" },
            .{ "UNKNOWN_RULE", "get_UNKNOWN_RULE" },
            .{ "SUPPORTS_RULE", "get_SUPPORTS_RULE" },
            .{ "KEYFRAMES_RULE", "get_KEYFRAMES_RULE" },
            .{ "KEYFRAME_RULE", "get_KEYFRAME_RULE" },
            .{ "COUNTER_STYLE_RULE", "get_COUNTER_STYLE_RULE" },
            .{ "FONT_FEATURE_VALUES_RULE", "get_FONT_FEATURE_VALUES_RULE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "parentRule", "get_parentRule", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "type", "get_type", null },
            .{ "type", "get_type", null },
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "parentRule", "get_parentRule", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cssText: CSSOMString = undefined,
            parentRule: ?*runtime.Instance = null,
            parentStyleSheet: ?*runtime.Instance = null,
            @"type": u16 = undefined,
            _internal: ?*CSSRuleImpl.InternalState = null,
        },
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

    const delegates = .{

        .get_CHARSET_RULE = &get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &get_MARGIN_RULE,
        .get_MEDIA_RULE = &get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &get_NAMESPACE_RULE,
        .get_PAGE_RULE = &get_PAGE_RULE,
        .get_STYLE_RULE = &get_STYLE_RULE,
        .get_SUPPORTS_RULE = &get_SUPPORTS_RULE,
        .get_UNKNOWN_RULE = &get_UNKNOWN_RULE,
        .get_cssText = &get_cssText,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_type = &get_type,

        .set_cssText = &set_cssText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSRuleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSRuleImpl.deinit(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSRuleImpl.get_parentRule(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSRuleImpl.get_type(instance);
    }

};

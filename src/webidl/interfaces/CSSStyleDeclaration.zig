//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSStyleDeclarationImpl = @import("impls").CSSStyleDeclaration;
const mixins = @import("mixins");
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSStyleDeclaration = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleDeclaration";
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
            .{ "length", "get_length", null },
            .{ "parentRule", "get_parentRule", null },
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "length", "get_length", null },
            .{ "parentRule", "get_parentRule", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "getPropertyValue", "call_getPropertyValue", 1 },
            .{ "getPropertyPriority", "call_getPropertyPriority", 1 },
            .{ "setProperty", "call_setProperty", 2 },
            .{ "removeProperty", "call_removeProperty", 1 },
            .{ "getPropertyValue", "call_getPropertyValue", 1 },
            .{ "getPropertyCSSValue", "call_getPropertyCSSValue", 1 },
            .{ "removeProperty", "call_removeProperty", 1 },
            .{ "getPropertyPriority", "call_getPropertyPriority", 1 },
            .{ "setProperty", "call_setProperty", 3 },
            .{ "item", "call_item", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "getPropertyValue",
            "getPropertyPriority",
            "setProperty",
            "removeProperty",
            "getPropertyValue",
            "getPropertyCSSValue",
            "removeProperty",
            "getPropertyPriority",
            "setProperty",
            "item",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "length", "get_length", null },
            .{ "parentRule", "get_parentRule", null },
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "length", "get_length", null },
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
            length: u32 = undefined,
            parentRule: ?*runtime.Instance = null,
            _internal: ?*CSSStyleDeclarationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_parentRule = &get_parentRule,

        .set_cssText = &set_cssText,

        .call_getPropertyCSSValue = &call_getPropertyCSSValue,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSStyleDeclarationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSStyleDeclarationImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSStyleDeclarationImpl.get_cssText(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSStyleDeclarationImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSStyleDeclarationImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSStyleDeclarationImpl.get_parentRule(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!CSSOMString {
        
        return try CSSStyleDeclarationImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeProperty(instance: *runtime.Instance, property: CSSOMString) anyerror!CSSOMString {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSStyleDeclarationImpl.call_removeProperty(instance, property);
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!*runtime.Instance {
        
        return try CSSStyleDeclarationImpl.call_getPropertyCSSValue(instance, propertyName);
    }

    pub fn call_getPropertyPriority(instance: *runtime.Instance, property: CSSOMString) anyerror!CSSOMString {
        
        return try CSSStyleDeclarationImpl.call_getPropertyPriority(instance, property);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setProperty(instance: *runtime.Instance, property: CSSOMString, value: CSSOMString, priority: webidl.Opt(CSSOMString)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSStyleDeclarationImpl.call_setProperty(instance, property, value, priority);
    }

    pub fn call_getPropertyValue(instance: *runtime.Instance, property: CSSOMString) anyerror!CSSOMString {
        
        return try CSSStyleDeclarationImpl.call_getPropertyValue(instance, property);
    }

};

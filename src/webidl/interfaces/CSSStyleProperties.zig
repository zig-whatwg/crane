//! Generated from: cssom.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSStylePropertiesImpl = @import("impls").CSSStyleProperties;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSStyleProperties = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleProperties";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleDeclaration;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            cssFloat: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSStyleProperties, .{
        .deinit_fn = &deinit_wrapper,

        .get_cssFloat = &get_cssFloat,
        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_parentRule = &get_parentRule,

        .set_cssFloat = &set_cssFloat,
        .set_cssText = &set_cssText,

        .call_getPropertyCSSValue = &call_getPropertyCSSValue,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSStylePropertiesImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSStylePropertiesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSStylePropertiesImpl.get_cssText(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSStylePropertiesImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSStylePropertiesImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSStylePropertiesImpl.get_parentRule(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_cssFloat(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSStylePropertiesImpl.get_cssFloat(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_cssFloat(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSStylePropertiesImpl.set_cssFloat(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try CSSStylePropertiesImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeProperty(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSStylePropertiesImpl.call_removeProperty(instance, property);
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSStylePropertiesImpl.call_getPropertyCSSValue(instance, propertyName);
    }

    pub fn call_getPropertyPriority(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        
        return try CSSStylePropertiesImpl.call_getPropertyPriority(instance, property);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setProperty(instance: *runtime.Instance, property: anyopaque, value: anyopaque, priority: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSStylePropertiesImpl.call_setProperty(instance, property, value, priority);
    }

    pub fn call_getPropertyValue(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        
        return try CSSStylePropertiesImpl.call_getPropertyValue(instance, property);
    }

};

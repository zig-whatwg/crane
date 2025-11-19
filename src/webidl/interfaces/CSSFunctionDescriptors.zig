//! Generated from: css-mixins.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFunctionDescriptorsImpl = @import("impls").CSSFunctionDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSFunctionDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSFunctionDescriptors";
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
            result: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSFunctionDescriptors, .{
        .deinit_fn = &deinit_wrapper,

        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_parentRule = &get_parentRule,
        .get_result = &get_result,

        .set_cssText = &set_cssText,
        .set_result = &set_result,

        .call_getPropertyCSSValue = &call_getPropertyCSSValue,
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSFunctionDescriptorsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSFunctionDescriptorsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSFunctionDescriptorsImpl.get_cssText(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSFunctionDescriptorsImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSFunctionDescriptorsImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSFunctionDescriptorsImpl.get_parentRule(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_result(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSFunctionDescriptorsImpl.get_result(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_result(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSFunctionDescriptorsImpl.set_result(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try CSSFunctionDescriptorsImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeProperty(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSFunctionDescriptorsImpl.call_removeProperty(instance, property);
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSFunctionDescriptorsImpl.call_getPropertyCSSValue(instance, propertyName);
    }

    pub fn call_getPropertyPriority(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        
        return try CSSFunctionDescriptorsImpl.call_getPropertyPriority(instance, property);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setProperty(instance: *runtime.Instance, property: anyopaque, value: anyopaque, priority: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSFunctionDescriptorsImpl.call_setProperty(instance, property, value, priority);
    }

    pub fn call_getPropertyValue(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        
        return try CSSFunctionDescriptorsImpl.call_getPropertyValue(instance, property);
    }

};

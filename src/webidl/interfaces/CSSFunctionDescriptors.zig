//! Generated from: css-mixins.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFunctionDescriptorsImpl = @import("impls").CSSFunctionDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;

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
        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_length = &get_length,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_result = &get_result,

        .set_cssText = &set_cssText,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSFunctionDescriptorsImpl.init(instance);
        
        return instance;
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

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSFunctionDescriptorsImpl.get_parentRule(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSFunctionDescriptorsImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
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

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyerror!anyopaque {
        switch (args) {
            .long => |arg| return try CSSFunctionDescriptorsImpl.long(instance, arg),
            .long => |arg| return try CSSFunctionDescriptorsImpl.long(instance, arg),
        }
    }

    /// Arguments for removeProperty (WebIDL overloading)
    pub const RemovePropertyArgs = union(enum) {
        /// removeProperty(property)
        CSSOMString: anyopaque,
        /// removeProperty(propertyName)
        string: DOMString,
    };

    pub fn call_removeProperty(instance: *runtime.Instance, args: RemovePropertyArgs) anyerror!anyopaque {
        switch (args) {
            .CSSOMString => |arg| return try CSSFunctionDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSFunctionDescriptorsImpl.string(instance, arg),
        }
    }

    /// Arguments for getPropertyPriority (WebIDL overloading)
    pub const GetPropertyPriorityArgs = union(enum) {
        /// getPropertyPriority(property)
        CSSOMString: anyopaque,
        /// getPropertyPriority(propertyName)
        string: DOMString,
    };

    pub fn call_getPropertyPriority(instance: *runtime.Instance, args: GetPropertyPriorityArgs) anyerror!anyopaque {
        switch (args) {
            .CSSOMString => |arg| return try CSSFunctionDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSFunctionDescriptorsImpl.string(instance, arg),
        }
    }

    /// Arguments for setProperty (WebIDL overloading)
    pub const SetPropertyArgs = union(enum) {
        /// setProperty(property, value, priority)
        CSSOMString_CSSOMString_CSSOMString: struct {
            property: anyopaque,
            value: anyopaque,
            priority: anyopaque,
        },
        /// setProperty(propertyName, value, priority)
        string_string_string: struct {
            propertyName: DOMString,
            value: DOMString,
            priority: DOMString,
        },
    };

    pub fn call_setProperty(instance: *runtime.Instance, args: SetPropertyArgs) anyerror!void {
        switch (args) {
            .CSSOMString_CSSOMString_CSSOMString => |a| return try CSSFunctionDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(instance, a.property, a.value, a.priority),
            .string_string_string => |a| return try CSSFunctionDescriptorsImpl.string_string_string(instance, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSFunctionDescriptorsImpl.call_getPropertyCSSValue(instance, propertyName);
    }

    /// Arguments for getPropertyValue (WebIDL overloading)
    pub const GetPropertyValueArgs = union(enum) {
        /// getPropertyValue(property)
        CSSOMString: anyopaque,
        /// getPropertyValue(propertyName)
        string: DOMString,
    };

    pub fn call_getPropertyValue(instance: *runtime.Instance, args: GetPropertyValueArgs) anyerror!anyopaque {
        switch (args) {
            .CSSOMString => |arg| return try CSSFunctionDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSFunctionDescriptorsImpl.string(instance, arg),
        }
    }

};

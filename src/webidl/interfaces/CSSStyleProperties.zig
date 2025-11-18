//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSStylePropertiesImpl = @import("impls").CSSStyleProperties;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;

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
        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_length = &get_length,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,

        .set_cssFloat = &set_cssFloat,
        .set_cssText = &set_cssText,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSStylePropertiesImpl.init(instance);
        
        return instance;
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

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSStylePropertiesImpl.get_parentRule(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSStylePropertiesImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
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

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyerror!anyopaque {
        switch (args) {
            .long => |arg| return try CSSStylePropertiesImpl.long(instance, arg),
            .long => |arg| return try CSSStylePropertiesImpl.long(instance, arg),
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
            .CSSOMString => |arg| return try CSSStylePropertiesImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSStylePropertiesImpl.string(instance, arg),
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
            .CSSOMString => |arg| return try CSSStylePropertiesImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSStylePropertiesImpl.string(instance, arg),
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
            .CSSOMString_CSSOMString_CSSOMString => |a| return try CSSStylePropertiesImpl.CSSOMString_CSSOMString_CSSOMString(instance, a.property, a.value, a.priority),
            .string_string_string => |a| return try CSSStylePropertiesImpl.string_string_string(instance, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSStylePropertiesImpl.call_getPropertyCSSValue(instance, propertyName);
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
            .CSSOMString => |arg| return try CSSStylePropertiesImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSStylePropertiesImpl.string(instance, arg),
        }
    }

};

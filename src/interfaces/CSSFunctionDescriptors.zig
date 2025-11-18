//! Generated from: css-mixins.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSFunctionDescriptorsImpl = @import("../impls/CSSFunctionDescriptors.zig");
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig");

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
        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,
        .call_setProperty = &call_setProperty,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSFunctionDescriptorsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSFunctionDescriptorsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_cssText(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        CSSFunctionDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_parentRule(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSFunctionDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_parentRule(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_result(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSFunctionDescriptorsImpl.get_result(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_result(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSFunctionDescriptorsImpl.set_result(state, value);
    }

    /// Arguments for item (WebIDL overloading)
    pub const ItemArgs = union(enum) {
        /// item(index)
        long: u32,
        /// item(index)
        long: u32,
    };

    pub fn call_item(instance: *runtime.Instance, args: ItemArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long => |arg| return CSSFunctionDescriptorsImpl.long(state, arg),
            .long => |arg| return CSSFunctionDescriptorsImpl.long(state, arg),
        }
    }

    /// Arguments for removeProperty (WebIDL overloading)
    pub const RemovePropertyArgs = union(enum) {
        /// removeProperty(property)
        CSSOMString: anyopaque,
        /// removeProperty(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_removeProperty(instance: *runtime.Instance, args: RemovePropertyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSFunctionDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSFunctionDescriptorsImpl.string(state, arg),
        }
    }

    /// Arguments for getPropertyPriority (WebIDL overloading)
    pub const GetPropertyPriorityArgs = union(enum) {
        /// getPropertyPriority(property)
        CSSOMString: anyopaque,
        /// getPropertyPriority(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_getPropertyPriority(instance: *runtime.Instance, args: GetPropertyPriorityArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSFunctionDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSFunctionDescriptorsImpl.string(state, arg),
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
            propertyName: runtime.DOMString,
            value: runtime.DOMString,
            priority: runtime.DOMString,
        },
    };

    pub fn call_setProperty(instance: *runtime.Instance, args: SetPropertyArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString_CSSOMString_CSSOMString => |a| return CSSFunctionDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(state, a.property, a.value, a.priority),
            .string_string_string => |a| return CSSFunctionDescriptorsImpl.string_string_string(state, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSFunctionDescriptorsImpl.call_getPropertyCSSValue(state, propertyName);
    }

    /// Arguments for getPropertyValue (WebIDL overloading)
    pub const GetPropertyValueArgs = union(enum) {
        /// getPropertyValue(property)
        CSSOMString: anyopaque,
        /// getPropertyValue(propertyName)
        string: runtime.DOMString,
    };

    pub fn call_getPropertyValue(instance: *runtime.Instance, args: GetPropertyValueArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CSSOMString => |arg| return CSSFunctionDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSFunctionDescriptorsImpl.string(state, arg),
        }
    }

};

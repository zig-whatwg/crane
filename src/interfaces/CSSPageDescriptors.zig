//! Generated from: cssom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPageDescriptorsImpl = @import("../impls/CSSPageDescriptors.zig");
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig");

pub const CSSPageDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSPageDescriptors";
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
            margin: CSSOMString = undefined,
            marginTop: CSSOMString = undefined,
            marginRight: CSSOMString = undefined,
            marginBottom: CSSOMString = undefined,
            marginLeft: CSSOMString = undefined,
            margin-top: CSSOMString = undefined,
            margin-right: CSSOMString = undefined,
            margin-bottom: CSSOMString = undefined,
            margin-left: CSSOMString = undefined,
            size: CSSOMString = undefined,
            pageOrientation: CSSOMString = undefined,
            page-orientation: CSSOMString = undefined,
            marks: CSSOMString = undefined,
            bleed: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSPageDescriptors, .{
        .deinit_fn = &deinit_wrapper,

        .get_bleed = &get_bleed,
        .get_cssText = &get_cssText,
        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_length = &get_length,
        .get_margin = &get_margin,
        .get_margin-bottom = &get_margin-bottom,
        .get_margin-left = &get_margin-left,
        .get_margin-right = &get_margin-right,
        .get_margin-top = &get_margin-top,
        .get_marginBottom = &get_marginBottom,
        .get_marginLeft = &get_marginLeft,
        .get_marginRight = &get_marginRight,
        .get_marginTop = &get_marginTop,
        .get_marks = &get_marks,
        .get_page-orientation = &get_page-orientation,
        .get_pageOrientation = &get_pageOrientation,
        .get_parentRule = &get_parentRule,
        .get_parentRule = &get_parentRule,
        .get_size = &get_size,

        .set_bleed = &set_bleed,
        .set_cssText = &set_cssText,
        .set_cssText = &set_cssText,
        .set_margin = &set_margin,
        .set_margin-bottom = &set_margin-bottom,
        .set_margin-left = &set_margin-left,
        .set_margin-right = &set_margin-right,
        .set_margin-top = &set_margin-top,
        .set_marginBottom = &set_marginBottom,
        .set_marginLeft = &set_marginLeft,
        .set_marginRight = &set_marginRight,
        .set_marginTop = &set_marginTop,
        .set_marks = &set_marks,
        .set_page-orientation = &set_page-orientation,
        .set_pageOrientation = &set_pageOrientation,
        .set_size = &set_size,

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
        CSSPageDescriptorsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_cssText(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        CSSPageDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_parentRule(state);
    }

    pub fn get_cssText(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_cssText(state);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_cssText(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_length(state);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_parentRule(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_margin(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_margin(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginTop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_marginTop(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginTop(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_marginTop(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginRight(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_marginRight(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginRight(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_marginRight(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginBottom(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_marginBottom(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginBottom(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_marginBottom(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginLeft(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_marginLeft(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginLeft(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_marginLeft(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-top(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_margin-top(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-top(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_margin-top(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-right(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_margin-right(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-right(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_margin-right(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-bottom(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_margin-bottom(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-bottom(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_margin-bottom(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-left(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_margin-left(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-left(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_margin-left(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_size(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_size(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_size(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_pageOrientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_pageOrientation(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_pageOrientation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_pageOrientation(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_page-orientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_page-orientation(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_page-orientation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_page-orientation(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_marks(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marks(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_marks(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_bleed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSPageDescriptorsImpl.get_bleed(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_bleed(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSPageDescriptorsImpl.set_bleed(state, value);
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
            .long => |arg| return CSSPageDescriptorsImpl.long(state, arg),
            .long => |arg| return CSSPageDescriptorsImpl.long(state, arg),
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
            .CSSOMString => |arg| return CSSPageDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSPageDescriptorsImpl.string(state, arg),
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
            .CSSOMString => |arg| return CSSPageDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSPageDescriptorsImpl.string(state, arg),
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
            .CSSOMString_CSSOMString_CSSOMString => |a| return CSSPageDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(state, a.property, a.value, a.priority),
            .string_string_string => |a| return CSSPageDescriptorsImpl.string_string_string(state, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CSSPageDescriptorsImpl.call_getPropertyCSSValue(state, propertyName);
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
            .CSSOMString => |arg| return CSSPageDescriptorsImpl.CSSOMString(state, arg),
            .string => |arg| return CSSPageDescriptorsImpl.string(state, arg),
        }
    }

};

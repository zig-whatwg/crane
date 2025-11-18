//! Generated from: cssom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPageDescriptorsImpl = @import("impls").CSSPageDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;

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
        CSSPageDescriptorsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPageDescriptorsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_cssText(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try CSSPageDescriptorsImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSPageDescriptorsImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_parentRule(instance);
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSPageDescriptorsImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSPageDescriptorsImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!CSSRule {
        return try CSSPageDescriptorsImpl.get_parentRule(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginTop(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_marginTop(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginTop(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginTop(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginRight(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_marginRight(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginRight(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginRight(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginBottom(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_marginBottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginBottom(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginBottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginLeft(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_marginLeft(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginLeft(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginLeft(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-top(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin-top(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-top(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin-top(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-right(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin-right(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-right(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin-right(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-bottom(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin-bottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-bottom(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin-bottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin-left(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin-left(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin-left(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin-left(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_size(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_size(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_size(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_size(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_pageOrientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_pageOrientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_pageOrientation(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_pageOrientation(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_page-orientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_page-orientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_page-orientation(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_page-orientation(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marks(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_marks(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marks(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_marks(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_bleed(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_bleed(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_bleed(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_bleed(instance, value);
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
            .long => |arg| return try CSSPageDescriptorsImpl.long(instance, arg),
            .long => |arg| return try CSSPageDescriptorsImpl.long(instance, arg),
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
            .CSSOMString => |arg| return try CSSPageDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSPageDescriptorsImpl.string(instance, arg),
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
            .CSSOMString => |arg| return try CSSPageDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSPageDescriptorsImpl.string(instance, arg),
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
            .CSSOMString_CSSOMString_CSSOMString => |a| return try CSSPageDescriptorsImpl.CSSOMString_CSSOMString_CSSOMString(instance, a.property, a.value, a.priority),
            .string_string_string => |a| return try CSSPageDescriptorsImpl.string_string_string(instance, a.propertyName, a.value, a.priority),
        }
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSPageDescriptorsImpl.call_getPropertyCSSValue(instance, propertyName);
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
            .CSSOMString => |arg| return try CSSPageDescriptorsImpl.CSSOMString(instance, arg),
            .string => |arg| return try CSSPageDescriptorsImpl.string(instance, arg),
        }
    }

};

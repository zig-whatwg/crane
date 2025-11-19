//! Generated from: cssom.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPageDescriptorsImpl = @import("impls").CSSPageDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("interfaces").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

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
            @"margin-top": CSSOMString = undefined,
            @"margin-right": CSSOMString = undefined,
            @"margin-bottom": CSSOMString = undefined,
            @"margin-left": CSSOMString = undefined,
            size: CSSOMString = undefined,
            pageOrientation: CSSOMString = undefined,
            @"page-orientation": CSSOMString = undefined,
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
        .get_length = &get_length,
        .get_margin = &get_margin,
        .get_marginBottom = &get_marginBottom,
        .get_marginLeft = &get_marginLeft,
        .get_marginRight = &get_marginRight,
        .get_marginTop = &get_marginTop,
        .get_margin_bottom = &get_margin_bottom,
        .get_margin_left = &get_margin_left,
        .get_margin_right = &get_margin_right,
        .get_margin_top = &get_margin_top,
        .get_marks = &get_marks,
        .get_pageOrientation = &get_pageOrientation,
        .get_page_orientation = &get_page_orientation,
        .get_parentRule = &get_parentRule,
        .get_size = &get_size,

        .set_bleed = &set_bleed,
        .set_cssText = &set_cssText,
        .set_margin = &set_margin,
        .set_marginBottom = &set_marginBottom,
        .set_marginLeft = &set_marginLeft,
        .set_marginRight = &set_marginRight,
        .set_marginTop = &set_marginTop,
        .set_margin_bottom = &set_margin_bottom,
        .set_margin_left = &set_margin_left,
        .set_margin_right = &set_margin_right,
        .set_margin_top = &set_margin_top,
        .set_marks = &set_marks,
        .set_pageOrientation = &set_pageOrientation,
        .set_page_orientation = &set_page_orientation,
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
        return CSSPageDescriptorsImpl.init(allocator, State, &vtable);
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
    pub fn get_margin_top(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin_top(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_top(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_top(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_right(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin_right(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_right(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_right(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_bottom(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin_bottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_bottom(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_bottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_left(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_margin_left(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_left(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_left(instance, value);
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
    pub fn get_page_orientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPageDescriptorsImpl.get_page_orientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_page_orientation(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSPageDescriptorsImpl.set_page_orientation(instance, value);
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

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try CSSPageDescriptorsImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeProperty(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSPageDescriptorsImpl.call_removeProperty(instance, property);
    }

    pub fn call_getPropertyCSSValue(instance: *runtime.Instance, propertyName: DOMString) anyerror!CSSValue {
        
        return try CSSPageDescriptorsImpl.call_getPropertyCSSValue(instance, propertyName);
    }

    pub fn call_getPropertyPriority(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        
        return try CSSPageDescriptorsImpl.call_getPropertyPriority(instance, property);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setProperty(instance: *runtime.Instance, property: anyopaque, value: anyopaque, priority: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CSSPageDescriptorsImpl.call_setProperty(instance, property, value, priority);
    }

    pub fn call_getPropertyValue(instance: *runtime.Instance, property: anyopaque) anyerror!anyopaque {
        
        return try CSSPageDescriptorsImpl.call_getPropertyValue(instance, property);
    }

};

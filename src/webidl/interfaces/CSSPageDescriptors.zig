//! Generated from: cssom.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPageDescriptorsImpl = @import("impls").CSSPageDescriptors;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;
const DOMString = @import("typedefs").DOMString;
const CSSValue = @import("interfaces").CSSValue;

pub const CSSPageDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSPageDescriptors";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleDeclaration;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "margin", "get_margin", "set_margin" },
            .{ "marginTop", "get_marginTop", "set_marginTop" },
            .{ "marginRight", "get_marginRight", "set_marginRight" },
            .{ "marginBottom", "get_marginBottom", "set_marginBottom" },
            .{ "marginLeft", "get_marginLeft", "set_marginLeft" },
            .{ "margin-top", "get_margin_top", "set_margin_top" },
            .{ "margin-right", "get_margin_right", "set_margin_right" },
            .{ "margin-bottom", "get_margin_bottom", "set_margin_bottom" },
            .{ "margin-left", "get_margin_left", "set_margin_left" },
            .{ "size", "get_size", "set_size" },
            .{ "pageOrientation", "get_pageOrientation", "set_pageOrientation" },
            .{ "page-orientation", "get_page_orientation", "set_page_orientation" },
            .{ "marks", "get_marks", "set_marks" },
            .{ "bleed", "get_bleed", "set_bleed" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
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
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "margin", "get_margin", "set_margin" },
            .{ "marginTop", "get_marginTop", "set_marginTop" },
            .{ "marginRight", "get_marginRight", "set_marginRight" },
            .{ "marginBottom", "get_marginBottom", "set_marginBottom" },
            .{ "marginLeft", "get_marginLeft", "set_marginLeft" },
            .{ "margin-top", "get_margin_top", "set_margin_top" },
            .{ "margin-right", "get_margin_right", "set_margin_right" },
            .{ "margin-bottom", "get_margin_bottom", "set_margin_bottom" },
            .{ "margin-left", "get_margin_left", "set_margin_left" },
            .{ "size", "get_size", "set_size" },
            .{ "pageOrientation", "get_pageOrientation", "set_pageOrientation" },
            .{ "page-orientation", "get_page_orientation", "set_page_orientation" },
            .{ "marks", "get_marks", "set_marks" },
            .{ "bleed", "get_bleed", "set_bleed" },
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
            _internal: ?*CSSPageDescriptorsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_bleed = &get_bleed,
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
        .get_size = &get_size,

        .set_bleed = &set_bleed,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSPageDescriptorsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPageDescriptorsImpl.deinit(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginTop(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginTop(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginTop(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginTop(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginRight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginRight(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginRight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginRight(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginBottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginBottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginBottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginBottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginLeft(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginLeft(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginLeft(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginLeft(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_top(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_top(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_top(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_top(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_right(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_right(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_right(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_right(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_bottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_bottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_bottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_bottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_left(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_left(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_left(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_left(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_size(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_size(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_pageOrientation(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_pageOrientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_pageOrientation(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_pageOrientation(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_page_orientation(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_page_orientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_page_orientation(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_page_orientation(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marks(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marks(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marks(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marks(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_bleed(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_bleed(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_bleed(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_bleed(instance, value);
    }

};

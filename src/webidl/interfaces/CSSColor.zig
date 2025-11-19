//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSColorImpl = @import("impls").CSSColor;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSKeywordish = @import("typedefs").CSSKeywordish;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSColor = struct {
    pub const Meta = struct {
        pub const name = "CSSColor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSColorValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            colorSpace: CSSKeywordish = undefined,
            channels: runtime.ObservableArray(CSSColorPercent) = undefined,
            alpha: CSSNumberish = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSColor, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_channels = &get_channels,
        .get_colorSpace = &get_colorSpace,

        .set_alpha = &set_alpha,
        .set_channels = &set_channels,
        .set_colorSpace = &set_colorSpace,

        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSColorImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSColorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, colorSpace: CSSKeywordish, channels: anyopaque, alpha: CSSNumberish) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSColorImpl.constructor(instance, colorSpace, channels, alpha);
        
        return instance;
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!CSSKeywordish {
        return try CSSColorImpl.get_colorSpace(instance);
    }

    pub fn set_colorSpace(instance: *runtime.Instance, value: CSSKeywordish) anyerror!void {
        try CSSColorImpl.set_colorSpace(instance, value);
    }

    pub fn get_channels(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSColorImpl.get_channels(instance);
    }

    pub fn set_channels(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSColorImpl.set_channels(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSColorImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSColorImpl.set_alpha(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSColorImpl.call_parseAll(instance, property, cssText);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!CSSStyleValue {
        
        return try CSSColorImpl.call_parse(instance, property, cssText);
    }

};

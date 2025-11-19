//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSHWBImpl = @import("impls").CSSHWB;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSHWB = struct {
    pub const Meta = struct {
        pub const name = "CSSHWB";
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
            h: CSSNumericValue = undefined,
            w: CSSNumberish = undefined,
            b: CSSNumberish = undefined,
            alpha: CSSNumberish = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSHWB, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_h = &get_h,
        .get_w = &get_w,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_h = &set_h,
        .set_w = &set_w,

        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CSSHWBImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSHWBImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, h: CSSNumericValue, w: CSSNumberish, b: CSSNumberish, alpha: CSSNumberish) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSHWBImpl.constructor(instance, h, w, b, alpha);
        
        return instance;
    }

    pub fn get_h(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSHWBImpl.get_h(instance);
    }

    pub fn set_h(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSHWBImpl.set_h(instance, value);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSHWBImpl.get_w(instance);
    }

    pub fn set_w(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSHWBImpl.set_w(instance, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSHWBImpl.get_b(instance);
    }

    pub fn set_b(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSHWBImpl.set_b(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSHWBImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSHWBImpl.set_alpha(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSHWBImpl.call_parseAll(instance, property, cssText);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parse(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!CSSStyleValue {
        
        return try CSSHWBImpl.call_parse(instance, property, cssText);
    }

};

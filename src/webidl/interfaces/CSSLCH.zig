//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSLCHImpl = @import("impls").CSSLCH;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSColorAngle = @import("typedefs").CSSColorAngle;
const CSSColorPercent = @import("typedefs").CSSColorPercent;

pub const CSSLCH = struct {
    pub const Meta = struct {
        pub const name = "CSSLCH";
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
            l: CSSColorPercent = undefined,
            c: CSSColorPercent = undefined,
            h: CSSColorAngle = undefined,
            alpha: CSSColorPercent = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSLCH, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_c = &get_c,
        .get_h = &get_h,
        .get_l = &get_l,

        .set_alpha = &set_alpha,
        .set_c = &set_c,
        .set_h = &set_h,
        .set_l = &set_l,

        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSLCHImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSLCHImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, l: CSSColorPercent, c: CSSColorPercent, h: CSSColorAngle, alpha: CSSColorPercent) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSLCHImpl.constructor(instance, l, c, h, alpha);
        
        return instance;
    }

    pub fn get_l(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSLCHImpl.get_l(instance);
    }

    pub fn set_l(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSLCHImpl.set_l(instance, value);
    }

    pub fn get_c(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSLCHImpl.get_c(instance);
    }

    pub fn set_c(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSLCHImpl.set_c(instance, value);
    }

    pub fn get_h(instance: *runtime.Instance) anyerror!CSSColorAngle {
        return try CSSLCHImpl.get_h(instance);
    }

    pub fn set_h(instance: *runtime.Instance, value: CSSColorAngle) anyerror!void {
        try CSSLCHImpl.set_h(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSLCHImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSLCHImpl.set_alpha(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSLCHImpl.call_parseAll(instance, property, cssText);
    }

    /// Arguments for parse (WebIDL overloading)
    pub const ParseArgs = union(enum) {
        /// parse(property, cssText)
        USVString_USVString: struct {
            property: runtime.USVString,
            cssText: runtime.USVString,
        },
        /// parse(cssText)
        USVString: runtime.USVString,
    };

    pub fn call_parse(instance: *runtime.Instance, args: ParseArgs) anyerror!CSSStyleValue {
        switch (args) {
            .USVString_USVString => |a| return try CSSLCHImpl.USVString_USVString(instance, a.property, a.cssText),
            .USVString => |arg| return try CSSLCHImpl.USVString(instance, arg),
        }
    }

};

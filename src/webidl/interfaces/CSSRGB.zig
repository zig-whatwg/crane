//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSRGBImpl = @import("impls").CSSRGB;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSColorRGBComp = @import("typedefs").CSSColorRGBComp;
const CSSColorPercent = @import("typedefs").CSSColorPercent;

pub const CSSRGB = struct {
    pub const Meta = struct {
        pub const name = "CSSRGB";
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
            r: CSSColorRGBComp = undefined,
            g: CSSColorRGBComp = undefined,
            b: CSSColorRGBComp = undefined,
            alpha: CSSColorPercent = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSRGB, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_g = &get_g,
        .get_r = &get_r,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_g = &set_g,
        .set_r = &set_r,

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
        CSSRGBImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSRGBImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, r: CSSColorRGBComp, g: CSSColorRGBComp, b: CSSColorRGBComp, alpha: CSSColorPercent) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSRGBImpl.constructor(instance, r, g, b, alpha);
        
        return instance;
    }

    pub fn get_r(instance: *runtime.Instance) anyerror!CSSColorRGBComp {
        return try CSSRGBImpl.get_r(instance);
    }

    pub fn set_r(instance: *runtime.Instance, value: CSSColorRGBComp) anyerror!void {
        try CSSRGBImpl.set_r(instance, value);
    }

    pub fn get_g(instance: *runtime.Instance) anyerror!CSSColorRGBComp {
        return try CSSRGBImpl.get_g(instance);
    }

    pub fn set_g(instance: *runtime.Instance, value: CSSColorRGBComp) anyerror!void {
        try CSSRGBImpl.set_g(instance, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyerror!CSSColorRGBComp {
        return try CSSRGBImpl.get_b(instance);
    }

    pub fn set_b(instance: *runtime.Instance, value: CSSColorRGBComp) anyerror!void {
        try CSSRGBImpl.set_b(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSRGBImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSRGBImpl.set_alpha(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSRGBImpl.call_parseAll(instance, property, cssText);
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
            .USVString_USVString => |a| return try CSSRGBImpl.USVString_USVString(instance, a.property, a.cssText),
            .USVString => |arg| return try CSSRGBImpl.USVString(instance, arg),
        }
    }

};

//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSLabImpl = @import("impls").CSSLab;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const CSSColorNumber = @import("typedefs").CSSColorNumber;

pub const CSSLab = struct {
    pub const Meta = struct {
        pub const name = "CSSLab";
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
            a: CSSColorNumber = undefined,
            b: CSSColorNumber = undefined,
            alpha: CSSColorPercent = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSLab, .{
        .deinit_fn = &deinit_wrapper,

        .get_a = &get_a,
        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_l = &get_l,

        .set_a = &set_a,
        .set_alpha = &set_alpha,
        .set_b = &set_b,
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
        CSSLabImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSLabImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, l: CSSColorPercent, a: CSSColorNumber, b: CSSColorNumber, alpha: CSSColorPercent) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSLabImpl.constructor(instance, l, a, b, alpha);
        
        return instance;
    }

    pub fn get_l(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSLabImpl.get_l(instance);
    }

    pub fn set_l(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSLabImpl.set_l(instance, value);
    }

    pub fn get_a(instance: *runtime.Instance) anyerror!CSSColorNumber {
        return try CSSLabImpl.get_a(instance);
    }

    pub fn set_a(instance: *runtime.Instance, value: CSSColorNumber) anyerror!void {
        try CSSLabImpl.set_a(instance, value);
    }

    pub fn get_b(instance: *runtime.Instance) anyerror!CSSColorNumber {
        return try CSSLabImpl.get_b(instance);
    }

    pub fn set_b(instance: *runtime.Instance, value: CSSColorNumber) anyerror!void {
        try CSSLabImpl.set_b(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSLabImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSLabImpl.set_alpha(instance, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyerror!anyopaque {
        
        return try CSSLabImpl.call_parseAll(instance, property, cssText);
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
            .USVString_USVString => |a| return try CSSLabImpl.USVString_USVString(instance, a.property, a.cssText),
            .USVString => |arg| return try CSSLabImpl.USVString(instance, arg),
        }
    }

};

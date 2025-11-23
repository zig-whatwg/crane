//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSRGBImpl = @import("impls").CSSRGB;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSColorRGBComp = @import("typedefs").CSSColorRGBComp;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSRGB = struct {
    pub const Meta = struct {
        pub const name = "CSSRGB";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSColorValue;
        pub const MixinTypes = &.{};
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "r", "get_r", "set_r" },
            .{ "g", "get_g", "set_g" },
            .{ "b", "get_b", "set_b" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
            "parse",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "r", "get_r", "set_r" },
            .{ "g", "get_g", "set_g" },
            .{ "b", "get_b", "set_b" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            r: CSSColorRGBComp = undefined,
            g: CSSColorRGBComp = undefined,
            b: CSSColorRGBComp = undefined,
            alpha: CSSColorPercent = undefined,
            _internal: ?*CSSRGBImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_g = &get_g,
        .get_r = &get_r,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_g = &set_g,
        .set_r = &set_r,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSRGBImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSRGBImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, r: CSSColorRGBComp, g: CSSColorRGBComp, b: CSSColorRGBComp, alpha: CSSColorPercent) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSRGBImpl.call_constructor(allocator, ctx, r, g, b, alpha);
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

};

//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T19:11:17Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSLCHImpl = @import("impls").CSSLCH;
const mixins = @import("mixins");
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSColorAngle = @import("typedefs").CSSColorAngle;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSLCH = struct {
    pub const Meta = struct {
        pub const name = "CSSLCH";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "l", "get_l", "set_l" },
            .{ "c", "get_c", "set_c" },
            .{ "h", "get_h", "set_h" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "l", "get_l", "set_l" },
            .{ "c", "get_c", "set_c" },
            .{ "h", "get_h", "set_h" },
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
            l: CSSColorPercent = undefined,
            c: CSSColorPercent = undefined,
            h: CSSColorAngle = undefined,
            alpha: CSSColorPercent = undefined,
            _internal: ?*CSSLCHImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alpha = &get_alpha,
        .get_c = &get_c,
        .get_h = &get_h,
        .get_l = &get_l,

        .set_alpha = &set_alpha,
        .set_c = &set_c,
        .set_h = &set_h,
        .set_l = &set_l,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSLCHImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSLCHImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, l: CSSColorPercent, c: CSSColorPercent, h: CSSColorAngle, alpha: webidl.Opt(CSSColorPercent)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSLCHImpl.call_constructor(allocator, ctx, l, c, h, alpha);
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

};

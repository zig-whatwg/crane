//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSLabImpl = @import("impls").CSSLab;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const USVString = @import("interfaces").USVString;
const CSSColorNumber = @import("typedefs").CSSColorNumber;
const DOMString = @import("typedefs").DOMString;

pub const CSSLab = struct {
    pub const Meta = struct {
        pub const name = "CSSLab";
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
            .{ "l", "get_l", "set_l" },
            .{ "a", "get_a", "set_a" },
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
            .{ "l", "get_l", "set_l" },
            .{ "a", "get_a", "set_a" },
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
            l: CSSColorPercent = undefined,
            a: CSSColorNumber = undefined,
            b: CSSColorNumber = undefined,
            alpha: CSSColorPercent = undefined,
            _internal: ?*CSSLabImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_a = &get_a,
        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_l = &get_l,

        .set_a = &set_a,
        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_l = &set_l,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSLabImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSLabImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, l: CSSColorPercent, a: CSSColorNumber, b: CSSColorNumber, alpha: CSSColorPercent) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSLabImpl.call_constructor(allocator, ctx, l, a, b, alpha);
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

};

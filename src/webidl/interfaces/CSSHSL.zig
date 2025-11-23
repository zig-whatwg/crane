//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSHSLImpl = @import("impls").CSSHSL;
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSColorAngle = @import("typedefs").CSSColorAngle;
const CSSColorPercent = @import("typedefs").CSSColorPercent;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSHSL = struct {
    pub const Meta = struct {
        pub const name = "CSSHSL";
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
            .{ "h", "get_h", "set_h" },
            .{ "s", "get_s", "set_s" },
            .{ "l", "get_l", "set_l" },
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
            .{ "h", "get_h", "set_h" },
            .{ "s", "get_s", "set_s" },
            .{ "l", "get_l", "set_l" },
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
            h: CSSColorAngle = undefined,
            s: CSSColorPercent = undefined,
            l: CSSColorPercent = undefined,
            alpha: CSSColorPercent = undefined,
            _internal: ?*CSSHSLImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alpha = &get_alpha,
        .get_h = &get_h,
        .get_l = &get_l,
        .get_s = &get_s,

        .set_alpha = &set_alpha,
        .set_h = &set_h,
        .set_l = &set_l,
        .set_s = &set_s,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSHSLImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSHSLImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, h: CSSColorAngle, s: CSSColorPercent, l: CSSColorPercent, alpha: CSSColorPercent) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSHSLImpl.call_constructor(allocator, ctx, h, s, l, alpha);
    }

    pub fn get_h(instance: *runtime.Instance) anyerror!CSSColorAngle {
        return try CSSHSLImpl.get_h(instance);
    }

    pub fn set_h(instance: *runtime.Instance, value: CSSColorAngle) anyerror!void {
        try CSSHSLImpl.set_h(instance, value);
    }

    pub fn get_s(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSHSLImpl.get_s(instance);
    }

    pub fn set_s(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSHSLImpl.set_s(instance, value);
    }

    pub fn get_l(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSHSLImpl.get_l(instance);
    }

    pub fn set_l(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSHSLImpl.set_l(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSColorPercent {
        return try CSSHSLImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSColorPercent) anyerror!void {
        try CSSHSLImpl.set_alpha(instance, value);
    }

};

//! Generated from: css-typed-om.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSHWBImpl = @import("impls").CSSHWB;
const mixins = @import("mixins");
const CSSColorValue = @import("interfaces").CSSColorValue;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSHWB = struct {
    pub const Meta = struct {
        pub const name = "CSSHWB";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSColorValue.State;
        pub const ParentInterface = CSSColorValue;
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
            .{ "w", "get_w", "set_w" },
            .{ "b", "get_b", "set_b" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
            "parse",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "h", "get_h", "set_h" },
            .{ "w", "get_w", "set_w" },
            .{ "b", "get_b", "set_b" },
            .{ "alpha", "get_alpha", "set_alpha" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            h: *runtime.Instance = undefined,
            w: CSSNumberish = undefined,
            b: CSSNumberish = undefined,
            alpha: CSSNumberish = undefined,
            _internal: ?*CSSHWBImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_alpha = &get_alpha,
        .get_b = &get_b,
        .get_h = &get_h,
        .get_w = &get_w,

        .set_alpha = &set_alpha,
        .set_b = &set_b,
        .set_h = &set_h,
        .set_w = &set_w,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSHWBImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSHWBImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, h: *runtime.Instance, w: CSSNumberish, b: CSSNumberish, alpha: webidl.Opt(CSSNumberish)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSHWBImpl.call_constructor(allocator, ctx, h, w, b, alpha);
    }

    pub fn get_h(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSHWBImpl.get_h(instance);
    }

    pub fn set_h(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
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
};

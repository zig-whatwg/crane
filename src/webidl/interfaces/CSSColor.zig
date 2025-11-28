//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSColorImpl = @import("impls").CSSColor;
const mixins = @import("mixins");
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
            .{ "colorSpace", "get_colorSpace", "set_colorSpace" },
            .{ "channels", "get_channels", "set_channels" },
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
            .{ "colorSpace", "get_colorSpace", "set_colorSpace" },
            .{ "channels", "get_channels", "set_channels" },
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
            colorSpace: CSSKeywordish = undefined,
            channels: runtime.ObservableArray(CSSColorPercent) = undefined,
            alpha: CSSNumberish = undefined,
            _internal: ?*CSSColorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alpha = &get_alpha,
        .get_channels = &get_channels,
        .get_colorSpace = &get_colorSpace,

        .set_alpha = &set_alpha,
        .set_channels = &set_channels,
        .set_colorSpace = &set_colorSpace,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSColorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSColorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, colorSpace: CSSKeywordish, channels: *const anyopaque, alpha: webidl.Opt(CSSNumberish)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSColorImpl.call_constructor(allocator, ctx, colorSpace, channels, alpha.value);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!CSSKeywordish {
        return try CSSColorImpl.get_colorSpace(instance);
    }

    pub fn set_colorSpace(instance: *runtime.Instance, value: CSSKeywordish) anyerror!void {
        try CSSColorImpl.set_colorSpace(instance, value);
    }

    pub fn get_channels(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CSSColorImpl.get_channels(instance);
    }

    pub fn set_channels(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try CSSColorImpl.set_channels(instance, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSColorImpl.get_alpha(instance);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSColorImpl.set_alpha(instance, value);
    }

};

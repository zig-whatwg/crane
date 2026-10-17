//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasShadowStylesImpl = @import("impls").CanvasShadowStyles;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const CanvasShadowStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasShadowStyles";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "shadowOffsetX", "get_shadowOffsetX", "set_shadowOffsetX" },
            .{ "shadowOffsetY", "get_shadowOffsetY", "set_shadowOffsetY" },
            .{ "shadowBlur", "get_shadowBlur", "set_shadowBlur" },
            .{ "shadowColor", "get_shadowColor", "set_shadowColor" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "shadowOffsetX", "get_shadowOffsetX", "set_shadowOffsetX" },
            .{ "shadowOffsetY", "get_shadowOffsetY", "set_shadowOffsetY" },
            .{ "shadowBlur", "get_shadowBlur", "set_shadowBlur" },
            .{ "shadowColor", "get_shadowColor", "set_shadowColor" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            shadowOffsetX: f64 = undefined,
            shadowOffsetY: f64 = undefined,
            shadowBlur: f64 = undefined,
            shadowColor: runtime.DOMString = undefined,
            _internal: ?*CanvasShadowStylesImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CanvasShadowStyles")) {
            if (comptime @hasDecl(impls.CanvasShadowStyles, "installHooks")) impls.CanvasShadowStyles.installHooks();
        }
    }

    pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasShadowStylesImpl.get_shadowOffsetX(instance);
    }

    pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowOffsetX(instance, value);
    }

    pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasShadowStylesImpl.get_shadowOffsetY(instance);
    }

    pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowOffsetY(instance, value);
    }

    pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasShadowStylesImpl.get_shadowBlur(instance);
    }

    pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowBlur(instance, value);
    }

    pub fn get_shadowColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try CanvasShadowStylesImpl.get_shadowColor(instance);
    }

    pub fn set_shadowColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowColor(instance, value);
    }
};

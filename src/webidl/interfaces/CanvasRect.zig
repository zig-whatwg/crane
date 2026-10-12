//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasRectImpl = @import("impls").CanvasRect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const CanvasRect = struct {
    pub const Meta = struct {
        pub const name = "CanvasRect";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clearRect", "call_clearRect", 4 },
            .{ "fillRect", "call_fillRect", 4 },
            .{ "strokeRect", "call_strokeRect", 4 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clearRect",
            "fillRect",
            "strokeRect",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CanvasRectImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CanvasRect")) {
            if (comptime @hasDecl(impls.CanvasRect, "installHooks")) impls.CanvasRect.installHooks();
        }
    }

    pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        return try CanvasRectImpl.call_strokeRect(instance, x, y, w, h);
    }

    pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        return try CanvasRectImpl.call_fillRect(instance, x, y, w, h);
    }

    pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        return try CanvasRectImpl.call_clearRect(instance, x, y, w, h);
    }
};

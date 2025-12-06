//! Generated from: html.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasTextImpl = @import("impls").CanvasText;
const mixins = @import("mixins");
const TextMetrics = @import("interfaces").TextMetrics;
const DOMString = @import("typedefs").DOMString;

pub const CanvasText = struct {
    pub const Meta = struct {
        pub const name = "CanvasText";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "fillText", "call_fillText", 3 },
            .{ "strokeText", "call_strokeText", 3 },
            .{ "measureText", "call_measureText", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fillText",
            "strokeText",
            "measureText",
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
            _internal: ?*CanvasTextImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_fillText = &call_fillText,
        .call_measureText = &call_measureText,
        .call_strokeText = &call_strokeText,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasTextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasTextImpl.deinit(instance);
    }

    pub fn call_strokeText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: webidl.Opt(f64)) anyerror!void {
        return try CanvasTextImpl.call_strokeText(instance, text, x, y, maxWidth);
    }

    pub fn call_fillText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: webidl.Opt(f64)) anyerror!void {
        return try CanvasTextImpl.call_fillText(instance, text, x, y, maxWidth);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: DOMString) anyerror!*runtime.Instance {
        return try CanvasTextImpl.call_measureText(instance, text);
    }
};

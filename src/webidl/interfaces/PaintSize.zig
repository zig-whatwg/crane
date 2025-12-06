//! Generated from: css-paint-api.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaintSizeImpl = @import("impls").PaintSize;
const mixins = @import("mixins");

pub const PaintSize = struct {
    pub const Meta = struct {
        pub const name = "PaintSize";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "PaintWorklet" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .PaintWorklet = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: f64 = undefined,
            height: f64 = undefined,
            _internal: ?*PaintSizeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_height = &get_height,
        .get_width = &get_width,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaintSizeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaintSizeImpl.deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try PaintSizeImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try PaintSizeImpl.get_height(instance);
    }
};

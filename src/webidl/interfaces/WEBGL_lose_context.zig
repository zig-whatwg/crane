//! Generated from: WEBGL_lose_context.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_lose_contextImpl = @import("impls").WEBGL_lose_context;
const mixins = @import("mixins");

pub const WEBGL_lose_context = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_lose_context";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "loseContext", "call_loseContext", 0 },
            .{ "restoreContext", "call_restoreContext", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "loseContext",
            "restoreContext",
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
            _internal: ?*WEBGL_lose_contextImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_loseContext = &call_loseContext,
        .call_restoreContext = &call_restoreContext,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_lose_contextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_lose_contextImpl.deinit(instance);
    }

    pub fn call_loseContext(instance: *runtime.Instance) anyerror!void {
        return try WEBGL_lose_contextImpl.call_loseContext(instance);
    }

    pub fn call_restoreContext(instance: *runtime.Instance) anyerror!void {
        return try WEBGL_lose_contextImpl.call_restoreContext(instance);
    }
};

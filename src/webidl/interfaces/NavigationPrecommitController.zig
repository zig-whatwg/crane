//! Generated from: html.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationPrecommitControllerImpl = @import("impls").NavigationPrecommitController;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;
const NavigationNavigateOptions = @import("dictionaries").NavigationNavigateOptions;

pub const NavigationPrecommitController = struct {
    pub const Meta = struct {
        pub const name = "NavigationPrecommitController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "redirect", "call_redirect", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "redirect",
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
            _internal: ?*NavigationPrecommitControllerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_redirect = &call_redirect,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationPrecommitControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationPrecommitControllerImpl.deinit(instance);
    }

    pub fn call_redirect(instance: *runtime.Instance, url: runtime.USVString, options: webidl.Opt(NavigationNavigateOptions)) anyerror!void {
        return try NavigationPrecommitControllerImpl.call_redirect(instance, url, options);
    }
};

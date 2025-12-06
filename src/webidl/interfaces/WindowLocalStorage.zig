//! Generated from: html.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowLocalStorageImpl = @import("impls").WindowLocalStorage;
const mixins = @import("mixins");
const Storage = @import("interfaces").Storage;

pub const WindowLocalStorage = struct {
    pub const Meta = struct {
        pub const name = "WindowLocalStorage";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "localStorage", "get_localStorage", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "localStorage", "get_localStorage", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            localStorage: *runtime.Instance = undefined,
            _internal: ?*WindowLocalStorageImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_localStorage = &get_localStorage,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowLocalStorageImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowLocalStorageImpl.deinit(instance);
    }

    pub fn get_localStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowLocalStorageImpl.get_localStorage(instance);
    }
};

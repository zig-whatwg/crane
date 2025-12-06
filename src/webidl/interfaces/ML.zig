//! Generated from: webnn.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLImpl = @import("impls").ML;
const mixins = @import("mixins");
const MLContextOptions = @import("dictionaries").MLContextOptions;
const MLContext = @import("interfaces").MLContext;
const GPUDevice = @import("interfaces").GPUDevice;

pub const ML = struct {
    pub const Meta = struct {
        pub const name = "ML";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
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
            .{ "createContext", "call_createContext", 0 },
            .{ "createContext", "call_createContext", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createContext",
            "createContext",
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
            _internal: ?*MLImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_createContext = &call_createContext,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MLImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLImpl.deinit(instance);
    }

    pub fn call_createContext(instance: *runtime.Instance, options: webidl.Opt(MLContextOptions)) anyerror!*const anyopaque {
        return try MLImpl.call_createContext(instance, options);
    }
};

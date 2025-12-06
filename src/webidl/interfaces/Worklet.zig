//! Generated from: html.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkletImpl = @import("impls").Worklet;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;
const WorkletOptions = @import("dictionaries").WorkletOptions;

pub const Worklet = struct {
    pub const Meta = struct {
        pub const name = "Worklet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addModule", "call_addModule", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addModule",
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
            _internal: ?*WorkletImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_addModule = &call_addModule,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkletImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkletImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.USVString, options: webidl.Opt(WorkletOptions)) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object

        return try WorkletImpl.call_addModule(instance, moduleURL, options);
    }
};

//! Generated from: screen-wake-lock.idl
//! Generated at: 2025-11-28T22:33:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WakeLockImpl = @import("impls").WakeLock;
const mixins = @import("mixins");
const WakeLockSentinel = @import("interfaces").WakeLockSentinel;
const WakeLockType = @import("enums").WakeLockType;

pub const WakeLock = struct {
    pub const Meta = struct {
        pub const name = "WakeLock";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "request", "call_request", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "request",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*WakeLockImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_request = &call_request,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WakeLockImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WakeLockImpl.deinit(instance);
    }

    pub fn call_request(instance: *runtime.Instance, @"type": webidl.Opt(WakeLockType)) anyerror!*const anyopaque {
        
        return try WakeLockImpl.call_request(instance, @"type");
    }

};

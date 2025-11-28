//! Generated from: web-app-launch.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LaunchQueueImpl = @import("impls").LaunchQueue;
const LaunchConsumer = @import("callbacks").LaunchConsumer;

pub const LaunchQueue = struct {
    pub const Meta = struct {
        pub const name = "LaunchQueue";
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
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setConsumer", "call_setConsumer", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setConsumer",
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
            _internal: ?*LaunchQueueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_setConsumer = &call_setConsumer,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LaunchQueueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LaunchQueueImpl.deinit(instance);
    }

    pub fn call_setConsumer(instance: *runtime.Instance, consumer: LaunchConsumer) anyerror!void {
        
        return try LaunchQueueImpl.call_setConsumer(instance, consumer);
    }

};

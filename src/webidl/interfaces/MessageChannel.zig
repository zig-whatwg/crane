//! Generated from: html.idl
//! Generated at: 2025-12-07T19:32:58Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const MessageChannelImpl = @import("impls").MessageChannel;
const mixins = @import("mixins");
const MessagePort = @import("interfaces").MessagePort;

pub const MessageChannel = struct {
    pub const Meta = struct {
        pub const name = "MessageChannel";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "port1", "get_port1", null },
            .{ "port2", "get_port2", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "port1", "get_port1", null },
            .{ "port2", "get_port2", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            port1: *runtime.Instance = undefined,
            port2: *runtime.Instance = undefined,
            _internal: ?*MessageChannelImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_port1 = &get_port1,
        .get_port2 = &get_port2,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MessageChannelImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MessageChannelImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MessageChannelImpl.call_constructor(allocator, ctx);
    }

    pub fn get_port1(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MessageChannelImpl.get_port1(instance);
    }

    pub fn get_port2(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MessageChannelImpl.get_port2(instance);
    }

};

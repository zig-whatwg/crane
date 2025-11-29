//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MulticastControllerImpl = @import("impls").MulticastController;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const MulticastController = struct {
    pub const Meta = struct {
        pub const name = "MulticastController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "joinedGroups", "get_joinedGroups", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "joinGroup", "call_joinGroup", 1 },
            .{ "leaveGroup", "call_leaveGroup", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "joinGroup",
            "leaveGroup",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "joinedGroups", "get_joinedGroups", null },
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
            joinedGroups: runtime.FrozenArray(runtime.DOMString) = undefined,
            _internal: ?*MulticastControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_joinedGroups = &get_joinedGroups,

        .call_joinGroup = &call_joinGroup,
        .call_leaveGroup = &call_leaveGroup,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MulticastControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MulticastControllerImpl.deinit(instance);
    }

    pub fn get_joinedGroups(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MulticastControllerImpl.get_joinedGroups(instance);
    }

    pub fn call_joinGroup(instance: *runtime.Instance, ipAddress: DOMString) anyerror!*const anyopaque {
        
        return try MulticastControllerImpl.call_joinGroup(instance, ipAddress);
    }

    pub fn call_leaveGroup(instance: *runtime.Instance, ipAddress: DOMString) anyerror!*const anyopaque {
        
        return try MulticastControllerImpl.call_leaveGroup(instance, ipAddress);
    }

};

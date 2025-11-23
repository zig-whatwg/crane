//! Generated from: push-api.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushSubscriptionOptionsImpl = @import("impls").PushSubscriptionOptions;

pub const PushSubscriptionOptions = struct {
    pub const Meta = struct {
        pub const name = "PushSubscriptionOptions";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "userVisibleOnly", "get_userVisibleOnly", null },
            .{ "applicationServerKey", "get_applicationServerKey", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "userVisibleOnly", "get_userVisibleOnly", null },
            .{ "applicationServerKey", "get_applicationServerKey", null },
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
            userVisibleOnly: bool = undefined,
            applicationServerKey: ?runtime.ArrayBuffer = null,
            cached_applicationServerKey: ?runtime.ArrayBuffer = null,
            _internal: ?*PushSubscriptionOptionsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_applicationServerKey = &get_applicationServerKey,
        .get_userVisibleOnly = &get_userVisibleOnly,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushSubscriptionOptionsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushSubscriptionOptionsImpl.deinit(instance);
    }

    pub fn get_userVisibleOnly(instance: *runtime.Instance) anyerror!bool {
        return try PushSubscriptionOptionsImpl.get_userVisibleOnly(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_applicationServerKey(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_applicationServerKey) |cached| {
            return cached;
        }
        const value = try PushSubscriptionOptionsImpl.get_applicationServerKey(instance);
        state.own.cached_applicationServerKey = value;
        return value;
    }

};

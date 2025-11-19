//! Generated from: push-api.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushManagerImpl = @import("impls").PushManager;
const PermissionState = @import("enums").PermissionState;
const PushSubscription = @import("interfaces").PushSubscription;
const PushSubscriptionOptionsInit = @import("dictionaries").PushSubscriptionOptionsInit;
const DOMString = @import("typedefs").DOMString;

pub const PushManager = struct {
    pub const Meta = struct {
        pub const name = "PushManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PushManager, .{
        .deinit_fn = &deinit_wrapper,

        .get_supportedContentEncodings = &get_supportedContentEncodings,

        .call_getSubscription = &call_getSubscription,
        .call_permissionState = &call_permissionState,
        .call_subscribe = &call_subscribe,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return PushManagerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_supportedContentEncodings(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_supportedContentEncodings) |cached| {
            return cached;
        }
        const value = try PushManagerImpl.get_supportedContentEncodings(instance);
        state.cached_supportedContentEncodings = value;
        return value;
    }

    pub fn call_permissionState(instance: *runtime.Instance, options: PushSubscriptionOptionsInit) anyerror!anyopaque {
        
        return try PushManagerImpl.call_permissionState(instance, options);
    }

    pub fn call_subscribe(instance: *runtime.Instance, options: PushSubscriptionOptionsInit) anyerror!anyopaque {
        
        return try PushManagerImpl.call_subscribe(instance, options);
    }

    pub fn call_getSubscription(instance: *runtime.Instance) anyerror!anyopaque {
        return try PushManagerImpl.call_getSubscription(instance);
    }

};

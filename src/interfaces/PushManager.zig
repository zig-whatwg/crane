//! Generated from: push-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushManagerImpl = @import("../impls/PushManager.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PushManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PushManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_supportedContentEncodings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_supportedContentEncodings) |cached| {
            return cached;
        }
        const value = PushManagerImpl.get_supportedContentEncodings(state);
        state.cached_supportedContentEncodings = value;
        return value;
    }

    pub fn call_permissionState(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PushManagerImpl.call_permissionState(state, options);
    }

    pub fn call_subscribe(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PushManagerImpl.call_subscribe(state, options);
    }

    pub fn call_getSubscription(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PushManagerImpl.call_getSubscription(state);
    }

};

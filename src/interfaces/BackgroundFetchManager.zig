//! Generated from: background-fetch.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchManagerImpl = @import("../impls/BackgroundFetchManager.zig");

pub const BackgroundFetchManager = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
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

    pub const vtable = runtime.buildVTable(BackgroundFetchManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_fetch = &call_fetch,
        .call_get = &call_get,
        .call_getIds = &call_getIds,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BackgroundFetchManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BackgroundFetchManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchManagerImpl.call_get(state, id);
    }

    pub fn call_fetch(instance: *runtime.Instance, id: runtime.DOMString, requests: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchManagerImpl.call_fetch(state, id, requests, options);
    }

    pub fn call_getIds(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchManagerImpl.call_getIds(state);
    }

};

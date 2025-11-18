//! Generated from: periodic-background-sync.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PeriodicSyncManagerImpl = @import("../impls/PeriodicSyncManager.zig");

pub const PeriodicSyncManager = struct {
    pub const Meta = struct {
        pub const name = "PeriodicSyncManager";
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

    pub const vtable = runtime.buildVTable(PeriodicSyncManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_getTags = &call_getTags,
        .call_register = &call_register,
        .call_unregister = &call_unregister,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PeriodicSyncManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PeriodicSyncManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getTags(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PeriodicSyncManagerImpl.call_getTags(state);
    }

    pub fn call_unregister(instance: *runtime.Instance, tag: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PeriodicSyncManagerImpl.call_unregister(state, tag);
    }

    pub fn call_register(instance: *runtime.Instance, tag: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PeriodicSyncManagerImpl.call_register(state, tag, options);
    }

};

//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageBucketManagerImpl = @import("../impls/StorageBucketManager.zig");

pub const StorageBucketManager = struct {
    pub const Meta = struct {
        pub const name = "StorageBucketManager";
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

    pub const vtable = runtime.buildVTable(StorageBucketManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_open = &call_open,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StorageBucketManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StorageBucketManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return StorageBucketManagerImpl.call_delete(state, name);
    }

    pub fn call_keys(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageBucketManagerImpl.call_keys(state);
    }

    pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return StorageBucketManagerImpl.call_open(state, name, options);
    }

};

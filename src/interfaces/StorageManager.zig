//! Generated from: storage.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageManagerImpl = @import("../impls/StorageManager.zig");

pub const StorageManager = struct {
    pub const Meta = struct {
        pub const name = "StorageManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
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

    pub const vtable = runtime.buildVTable(StorageManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_estimate = &call_estimate,
        .call_getDirectory = &call_getDirectory,
        .call_persist = &call_persist,
        .call_persisted = &call_persisted,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StorageManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StorageManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageManagerImpl.call_getDirectory(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageManagerImpl.call_persist(state);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageManagerImpl.call_estimate(state);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageManagerImpl.call_persisted(state);
    }

};

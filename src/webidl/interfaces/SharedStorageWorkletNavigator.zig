//! Generated from: shared-storage.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorkletNavigatorImpl = @import("impls").SharedStorageWorkletNavigator;
const NavigatorLocks = @import("interfaces").NavigatorLocks;
const LockManager = @import("interfaces").LockManager;

pub const SharedStorageWorkletNavigator = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorkletNavigator";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            NavigatorLocks,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "SharedStorageWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedStorageWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            locks: LockManager = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedStorageWorkletNavigator, .{
        .deinit_fn = &deinit_wrapper,

        .get_locks = &get_locks,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SharedStorageWorkletNavigatorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageWorkletNavigatorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locks(instance: *runtime.Instance) anyerror!LockManager {
        return try SharedStorageWorkletNavigatorImpl.get_locks(instance);
    }

};

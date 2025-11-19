//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorStorageBucketsImpl = @import("impls").NavigatorStorageBuckets;
const StorageBucketManager = @import("interfaces").StorageBucketManager;

pub const NavigatorStorageBuckets = struct {
    pub const Meta = struct {
        pub const name = "NavigatorStorageBuckets";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            storageBuckets: StorageBucketManager = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorStorageBuckets, .{
        .deinit_fn = &deinit_wrapper,

        .get_storageBuckets = &get_storageBuckets,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NavigatorStorageBucketsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorStorageBucketsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_storageBuckets(instance: *runtime.Instance) anyerror!StorageBucketManager {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_storageBuckets) |cached| {
            return cached;
        }
        const value = try NavigatorStorageBucketsImpl.get_storageBuckets(instance);
        state.cached_storageBuckets = value;
        return value;
    }

};

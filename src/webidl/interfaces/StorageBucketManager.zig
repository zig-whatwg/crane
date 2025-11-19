//! Generated from: storage-buckets.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageBucketManagerImpl = @import("impls").StorageBucketManager;
const StorageBucketOptions = @import("dictionaries").StorageBucketOptions;
const StorageBucket = @import("interfaces").StorageBucket;
const DOMString = @import("typedefs").DOMString;

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
        return StorageBucketManagerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageBucketManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try StorageBucketManagerImpl.call_delete(instance, name);
    }

    pub fn call_keys(instance: *runtime.Instance) anyerror!anyopaque {
        return try StorageBucketManagerImpl.call_keys(instance);
    }

    pub fn call_open(instance: *runtime.Instance, name: DOMString, options: StorageBucketOptions) anyerror!anyopaque {
        
        return try StorageBucketManagerImpl.call_open(instance, name, options);
    }

};

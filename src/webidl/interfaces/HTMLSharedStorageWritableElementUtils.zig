//! Generated from: shared-storage.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLSharedStorageWritableElementUtilsImpl = @import("impls").HTMLSharedStorageWritableElementUtils;

pub const HTMLSharedStorageWritableElementUtils = struct {
    pub const Meta = struct {
        pub const name = "HTMLSharedStorageWritableElementUtils";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            sharedStorageWritable: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HTMLSharedStorageWritableElementUtils, .{
        .deinit_fn = &deinit_wrapper,

        .get_sharedStorageWritable = &get_sharedStorageWritable,

        .set_sharedStorageWritable = &set_sharedStorageWritable,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        HTMLSharedStorageWritableElementUtilsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLSharedStorageWritableElementUtilsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSharedStorageWritableElementUtilsImpl.get_sharedStorageWritable(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSharedStorageWritableElementUtilsImpl.set_sharedStorageWritable(instance, value);
    }

};

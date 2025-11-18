//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoColorSpaceImpl = @import("impls").VideoColorSpace;
const VideoMatrixCoefficients = @import("enums").VideoMatrixCoefficients;
const VideoColorSpaceInit = @import("dictionaries").VideoColorSpaceInit;
const boolean = @import("interfaces").boolean;
const VideoColorPrimaries = @import("enums").VideoColorPrimaries;
const VideoTransferCharacteristics = @import("enums").VideoTransferCharacteristics;

pub const VideoColorSpace = struct {
    pub const Meta = struct {
        pub const name = "VideoColorSpace";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            primaries: ?VideoColorPrimaries = null,
            transfer: ?VideoTransferCharacteristics = null,
            matrix: ?VideoMatrixCoefficients = null,
            fullRange: ?bool = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoColorSpace, .{
        .deinit_fn = &deinit_wrapper,

        .get_fullRange = &get_fullRange,
        .get_matrix = &get_matrix,
        .get_primaries = &get_primaries,
        .get_transfer = &get_transfer,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        VideoColorSpaceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoColorSpaceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: VideoColorSpaceInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VideoColorSpaceImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_primaries(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoColorSpaceImpl.get_primaries(instance);
    }

    pub fn get_transfer(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoColorSpaceImpl.get_transfer(instance);
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoColorSpaceImpl.get_matrix(instance);
    }

    pub fn get_fullRange(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoColorSpaceImpl.get_fullRange(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!VideoColorSpaceInit {
        return try VideoColorSpaceImpl.call_toJSON(instance);
    }

};

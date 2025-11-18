//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoColorSpaceImpl = @import("../impls/VideoColorSpace.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        VideoColorSpaceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VideoColorSpaceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try VideoColorSpaceImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_primaries(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoColorSpaceImpl.get_primaries(state);
    }

    pub fn get_transfer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoColorSpaceImpl.get_transfer(state);
    }

    pub fn get_matrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoColorSpaceImpl.get_matrix(state);
    }

    pub fn get_fullRange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoColorSpaceImpl.get_fullRange(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoColorSpaceImpl.call_toJSON(state);
    }

};

//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EncodedAudioChunkImpl = @import("../impls/EncodedAudioChunk.zig");

pub const EncodedAudioChunk = struct {
    pub const Meta = struct {
        pub const name = "EncodedAudioChunk";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: EncodedAudioChunkType = undefined,
            timestamp: i64 = undefined,
            duration: ?u64 = null,
            byteLength: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(EncodedAudioChunk, .{
        .deinit_fn = &deinit_wrapper,

        .get_byteLength = &get_byteLength,
        .get_duration = &get_duration,
        .get_timestamp = &get_timestamp,
        .get_type = &get_type,

        .call_copyTo = &call_copyTo,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        EncodedAudioChunkImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        EncodedAudioChunkImpl.deinit(state);
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
        try EncodedAudioChunkImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EncodedAudioChunkImpl.get_type(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return EncodedAudioChunkImpl.get_timestamp(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EncodedAudioChunkImpl.get_duration(state);
    }

    pub fn get_byteLength(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return EncodedAudioChunkImpl.get_byteLength(state);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EncodedAudioChunkImpl.call_copyTo(state, destination);
    }

};

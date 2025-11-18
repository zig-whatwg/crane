//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EncodedAudioChunkImpl = @import("impls").EncodedAudioChunk;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const EncodedAudioChunkType = @import("enums").EncodedAudioChunkType;
const unsigned long long = @import("interfaces").unsigned long long;
const EncodedAudioChunkInit = @import("dictionaries").EncodedAudioChunkInit;

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
        
        // Initialize the instance (Impl receives full instance)
        EncodedAudioChunkImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EncodedAudioChunkImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: EncodedAudioChunkInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try EncodedAudioChunkImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!EncodedAudioChunkType {
        return try EncodedAudioChunkImpl.get_type(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try EncodedAudioChunkImpl.get_timestamp(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!anyopaque {
        return try EncodedAudioChunkImpl.get_duration(instance);
    }

    pub fn get_byteLength(instance: *runtime.Instance) anyerror!u32 {
        return try EncodedAudioChunkImpl.get_byteLength(instance);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource) anyerror!void {
        
        return try EncodedAudioChunkImpl.call_copyTo(instance, destination);
    }

};

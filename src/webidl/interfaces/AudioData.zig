//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioDataImpl = @import("impls").AudioData;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const AudioDataInit = @import("dictionaries").AudioDataInit;
const AudioDataCopyToOptions = @import("dictionaries").AudioDataCopyToOptions;
const AudioSampleFormat = @import("enums").AudioSampleFormat;

pub const AudioData = struct {
    pub const Meta = struct {
        pub const name = "AudioData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            format: ?AudioSampleFormat = null,
            sampleRate: f32 = undefined,
            numberOfFrames: u32 = undefined,
            numberOfChannels: u32 = undefined,
            duration: u64 = undefined,
            timestamp: i64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioData, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_format = &get_format,
        .get_numberOfChannels = &get_numberOfChannels,
        .get_numberOfFrames = &get_numberOfFrames,
        .get_sampleRate = &get_sampleRate,
        .get_timestamp = &get_timestamp,

        .call_allocationSize = &call_allocationSize,
        .call_clone = &call_clone,
        .call_close = &call_close,
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
        AudioDataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: AudioDataInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AudioDataImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!anyopaque {
        return try AudioDataImpl.get_format(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioDataImpl.get_sampleRate(instance);
    }

    pub fn get_numberOfFrames(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDataImpl.get_numberOfFrames(instance);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDataImpl.get_numberOfChannels(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!u64 {
        return try AudioDataImpl.get_duration(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try AudioDataImpl.get_timestamp(instance);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: AudioDataCopyToOptions) anyerror!u32 {
        
        return try AudioDataImpl.call_allocationSize(instance, options);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource, options: AudioDataCopyToOptions) anyerror!void {
        
        return try AudioDataImpl.call_copyTo(instance, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!AudioData {
        return try AudioDataImpl.call_clone(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioDataImpl.call_close(instance);
    }

};

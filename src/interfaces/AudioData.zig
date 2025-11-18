//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioDataImpl = @import("../impls/AudioData.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        AudioDataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioDataImpl.deinit(state);
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
        try AudioDataImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_format(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDataImpl.get_format(state);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return AudioDataImpl.get_sampleRate(state);
    }

    pub fn get_numberOfFrames(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioDataImpl.get_numberOfFrames(state);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioDataImpl.get_numberOfChannels(state);
    }

    pub fn get_duration(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return AudioDataImpl.get_duration(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return AudioDataImpl.get_timestamp(state);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: anyopaque) u32 {
        const state = instance.getState(State);
        
        return AudioDataImpl.call_allocationSize(state, options);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDataImpl.call_copyTo(state, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDataImpl.call_clone(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDataImpl.call_close(state);
    }

};

//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioBufferImpl = @import("../impls/AudioBuffer.zig");

pub const AudioBuffer = struct {
    pub const Meta = struct {
        pub const name = "AudioBuffer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sampleRate: f32 = undefined,
            length: u32 = undefined,
            duration: f64 = undefined,
            numberOfChannels: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioBuffer, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_length = &get_length,
        .get_numberOfChannels = &get_numberOfChannels,
        .get_sampleRate = &get_sampleRate,

        .call_copyFromChannel = &call_copyFromChannel,
        .call_copyToChannel = &call_copyToChannel,
        .call_getChannelData = &call_getChannelData,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AudioBufferImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioBufferImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try AudioBufferImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_sampleRate(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return AudioBufferImpl.get_sampleRate(state);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioBufferImpl.get_length(state);
    }

    pub fn get_duration(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AudioBufferImpl.get_duration(state);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioBufferImpl.get_numberOfChannels(state);
    }

    pub fn call_getChannelData(instance: *runtime.Instance, channel: u32) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferImpl.call_getChannelData(state, channel);
    }

    pub fn call_copyFromChannel(instance: *runtime.Instance, destination: anyopaque, channelNumber: u32, bufferOffset: u32) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferImpl.call_copyFromChannel(state, destination, channelNumber, bufferOffset);
    }

    pub fn call_copyToChannel(instance: *runtime.Instance, source: anyopaque, channelNumber: u32, bufferOffset: u32) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferImpl.call_copyToChannel(state, source, channelNumber, bufferOffset);
    }

};

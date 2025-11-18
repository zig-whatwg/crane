//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpReceiverImpl = @import("../impls/RTCRtpReceiver.zig");

pub const RTCRtpReceiver = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpReceiver";
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
            track: MediaStreamTrack = undefined,
            transport: ?RTCDtlsTransport = null,
            jitterBufferTarget: ?DOMHighResTimeStamp = null,
            transform: ?RTCRtpTransform = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCRtpReceiver, .{
        .deinit_fn = &deinit_wrapper,

        .get_jitterBufferTarget = &get_jitterBufferTarget,
        .get_track = &get_track,
        .get_transform = &get_transform,
        .get_transport = &get_transport,

        .set_jitterBufferTarget = &set_jitterBufferTarget,
        .set_transform = &set_transform,

        .call_getCapabilities = &call_getCapabilities,
        .call_getContributingSources = &call_getContributingSources,
        .call_getParameters = &call_getParameters,
        .call_getStats = &call_getStats,
        .call_getSynchronizationSources = &call_getSynchronizationSources,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCRtpReceiverImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCRtpReceiverImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.get_track(state);
    }

    pub fn get_transport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.get_transport(state);
    }

    pub fn get_jitterBufferTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.get_jitterBufferTarget(state);
    }

    pub fn set_jitterBufferTarget(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCRtpReceiverImpl.set_jitterBufferTarget(state, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.get_transform(state);
    }

    pub fn set_transform(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCRtpReceiverImpl.set_transform(state, value);
    }

    pub fn call_getContributingSources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.call_getContributingSources(state);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance, kind: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpReceiverImpl.call_getCapabilities(state, kind);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.call_getStats(state);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.call_getParameters(state);
    }

    pub fn call_getSynchronizationSources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpReceiverImpl.call_getSynchronizationSources(state);
    }

};

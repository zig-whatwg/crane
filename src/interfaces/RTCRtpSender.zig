//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpSenderImpl = @import("../impls/RTCRtpSender.zig");

pub const RTCRtpSender = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpSender";
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
            track: ?MediaStreamTrack = null,
            transport: ?RTCDtlsTransport = null,
            dtmf: ?RTCDTMFSender = null,
            transform: ?RTCRtpTransform = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCRtpSender, .{
        .deinit_fn = &deinit_wrapper,

        .get_dtmf = &get_dtmf,
        .get_track = &get_track,
        .get_transform = &get_transform,
        .get_transport = &get_transport,

        .set_transform = &set_transform,

        .call_getCapabilities = &call_getCapabilities,
        .call_getParameters = &call_getParameters,
        .call_getStats = &call_getStats,
        .call_replaceTrack = &call_replaceTrack,
        .call_setParameters = &call_setParameters,
        .call_setStreams = &call_setStreams,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCRtpSenderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCRtpSenderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpSenderImpl.get_track(state);
    }

    pub fn get_transport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpSenderImpl.get_transport(state);
    }

    pub fn get_dtmf(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpSenderImpl.get_dtmf(state);
    }

    pub fn get_transform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpSenderImpl.get_transform(state);
    }

    pub fn set_transform(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCRtpSenderImpl.set_transform(state, value);
    }

    pub fn call_replaceTrack(instance: *runtime.Instance, withTrack: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpSenderImpl.call_replaceTrack(state, withTrack);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance, kind: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpSenderImpl.call_getCapabilities(state, kind);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpSenderImpl.call_getStats(state);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpSenderImpl.call_getParameters(state);
    }

    pub fn call_setStreams(instance: *runtime.Instance, streams: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpSenderImpl.call_setStreams(state, streams);
    }

    pub fn call_setParameters(instance: *runtime.Instance, parameters: anyopaque, setParameterOptions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpSenderImpl.call_setParameters(state, parameters, setParameterOptions);
    }

};

//! Generated from: webrtc.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpReceiverImpl = @import("impls").RTCRtpReceiver;
const RTCRtpCapabilities = @import("dictionaries").RTCRtpCapabilities;
const RTCRtpReceiveParameters = @import("dictionaries").RTCRtpReceiveParameters;
const RTCRtpSynchronizationSource = @import("dictionaries").RTCRtpSynchronizationSource;
const RTCStatsReport = @import("interfaces").RTCStatsReport;
const RTCRtpTransform = @import("typedefs").RTCRtpTransform;
const RTCDtlsTransport = @import("interfaces").RTCDtlsTransport;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const RTCRtpContributingSource = @import("dictionaries").RTCRtpContributingSource;
const DOMString = @import("typedefs").DOMString;

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
        return RTCRtpReceiverImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpReceiverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!MediaStreamTrack {
        return try RTCRtpReceiverImpl.get_track(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!RTCDtlsTransport {
        return try RTCRtpReceiverImpl.get_transport(instance);
    }

    pub fn get_jitterBufferTarget(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try RTCRtpReceiverImpl.get_jitterBufferTarget(instance);
    }

    pub fn set_jitterBufferTarget(instance: *runtime.Instance, value: DOMHighResTimeStamp) anyerror!void {
        try RTCRtpReceiverImpl.set_jitterBufferTarget(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!RTCRtpTransform {
        return try RTCRtpReceiverImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: RTCRtpTransform) anyerror!void {
        try RTCRtpReceiverImpl.set_transform(instance, value);
    }

    pub fn call_getContributingSources(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpReceiverImpl.call_getContributingSources(instance);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance, kind: DOMString) anyerror!RTCRtpCapabilities {
        
        return try RTCRtpReceiverImpl.call_getCapabilities(instance, kind);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpReceiverImpl.call_getStats(instance);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!RTCRtpReceiveParameters {
        return try RTCRtpReceiverImpl.call_getParameters(instance);
    }

    pub fn call_getSynchronizationSources(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpReceiverImpl.call_getSynchronizationSources(instance);
    }

};

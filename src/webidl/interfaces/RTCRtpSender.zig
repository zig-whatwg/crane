//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpSenderImpl = @import("impls").RTCRtpSender;
const RTCRtpCapabilities = @import("dictionaries").RTCRtpCapabilities;
const Promise<RTCStatsReport> = @import("interfaces").Promise<RTCStatsReport>;
const RTCSetParameterOptions = @import("dictionaries").RTCSetParameterOptions;
const MediaStream = @import("interfaces").MediaStream;
const RTCRtpSendParameters = @import("dictionaries").RTCRtpSendParameters;
const RTCRtpTransform = @import("typedefs").RTCRtpTransform;
const RTCDtlsTransport = @import("interfaces").RTCDtlsTransport;
const RTCDTMFSender = @import("interfaces").RTCDTMFSender;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const Promise<undefined> = @import("interfaces").Promise<undefined>;

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
        
        // Initialize the instance (Impl receives full instance)
        RTCRtpSenderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpSenderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpSenderImpl.get_track(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpSenderImpl.get_transport(instance);
    }

    pub fn get_dtmf(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpSenderImpl.get_dtmf(instance);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpSenderImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try RTCRtpSenderImpl.set_transform(instance, value);
    }

    pub fn call_replaceTrack(instance: *runtime.Instance, withTrack: anyopaque) anyerror!anyopaque {
        
        return try RTCRtpSenderImpl.call_replaceTrack(instance, withTrack);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance, kind: DOMString) anyerror!anyopaque {
        
        return try RTCRtpSenderImpl.call_getCapabilities(instance, kind);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpSenderImpl.call_getStats(instance);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!RTCRtpSendParameters {
        return try RTCRtpSenderImpl.call_getParameters(instance);
    }

    pub fn call_setStreams(instance: *runtime.Instance, streams: MediaStream) anyerror!void {
        
        return try RTCRtpSenderImpl.call_setStreams(instance, streams);
    }

    pub fn call_setParameters(instance: *runtime.Instance, parameters: RTCRtpSendParameters, setParameterOptions: RTCSetParameterOptions) anyerror!anyopaque {
        
        return try RTCRtpSenderImpl.call_setParameters(instance, parameters, setParameterOptions);
    }

};

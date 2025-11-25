//! Generated from: webrtc.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpSenderImpl = @import("impls").RTCRtpSender;
const RTCRtpCapabilities = @import("dictionaries").RTCRtpCapabilities;
const RTCSetParameterOptions = @import("dictionaries").RTCSetParameterOptions;
const MediaStream = @import("interfaces").MediaStream;
const RTCRtpSendParameters = @import("dictionaries").RTCRtpSendParameters;
const RTCStatsReport = @import("interfaces").RTCStatsReport;
const RTCDtlsTransport = @import("interfaces").RTCDtlsTransport;
const RTCDTMFSender = @import("interfaces").RTCDTMFSender;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const RTCRtpTransform = @import("typedefs").RTCRtpTransform;
const DOMString = @import("typedefs").DOMString;

pub const RTCRtpSender = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpSender";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "track", "get_track", null },
            .{ "transport", "get_transport", null },
            .{ "dtmf", "get_dtmf", null },
            .{ "transform", "get_transform", "set_transform" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setParameters", "call_setParameters", 1 },
            .{ "getParameters", "call_getParameters", 0 },
            .{ "replaceTrack", "call_replaceTrack", 1 },
            .{ "setStreams", "call_setStreams", 1 },
            .{ "getStats", "call_getStats", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "getCapabilities", "call_getCapabilities", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCapabilities",
            "setParameters",
            "getParameters",
            "replaceTrack",
            "setStreams",
            "getStats",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
            .{ "transport", "get_transport", null },
            .{ "dtmf", "get_dtmf", null },
            .{ "transform", "get_transform", "set_transform" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            track: ?*runtime.Instance = null,
            transport: ?*runtime.Instance = null,
            dtmf: ?*runtime.Instance = null,
            transform: ?RTCRtpTransform = null,
            _internal: ?*RTCRtpSenderImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCRtpSenderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpSenderImpl.deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCRtpSenderImpl.get_track(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCRtpSenderImpl.get_transport(instance);
    }

    pub fn get_dtmf(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCRtpSenderImpl.get_dtmf(instance);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!?RTCRtpTransform {
        return try RTCRtpSenderImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: RTCRtpTransform) anyerror!void {
        try RTCRtpSenderImpl.set_transform(instance, value);
    }

    pub fn call_replaceTrack(instance: *runtime.Instance, withTrack: *runtime.Instance) anyerror!*const anyopaque {
        
        return try RTCRtpSenderImpl.call_replaceTrack(instance, withTrack);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance, kind: DOMString) anyerror!?RTCRtpCapabilities {
        
        return try RTCRtpSenderImpl.call_getCapabilities(instance, kind);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCRtpSenderImpl.call_getStats(instance);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!RTCRtpSendParameters {
        return try RTCRtpSenderImpl.call_getParameters(instance);
    }

    pub fn call_setStreams(instance: *runtime.Instance, streams: *runtime.Instance) anyerror!void {
        
        return try RTCRtpSenderImpl.call_setStreams(instance, streams);
    }

    pub fn call_setParameters(instance: *runtime.Instance, parameters: RTCRtpSendParameters, setParameterOptions: RTCSetParameterOptions) anyerror!*const anyopaque {
        
        return try RTCRtpSenderImpl.call_setParameters(instance, parameters, setParameterOptions);
    }

};

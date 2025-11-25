//! Generated from: webrtc.idl
//! Generated at: 2025-11-25T19:42:24Z
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
            .{ "jitterBufferTarget", "get_jitterBufferTarget", "set_jitterBufferTarget" },
            .{ "transform", "get_transform", "set_transform" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getParameters", "call_getParameters", 0 },
            .{ "getContributingSources", "call_getContributingSources", 0 },
            .{ "getSynchronizationSources", "call_getSynchronizationSources", 0 },
            .{ "getStats", "call_getStats", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "getCapabilities", "call_getCapabilities", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCapabilities",
            "getParameters",
            "getContributingSources",
            "getSynchronizationSources",
            "getStats",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
            .{ "transport", "get_transport", null },
            .{ "jitterBufferTarget", "get_jitterBufferTarget", "set_jitterBufferTarget" },
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
            track: *runtime.Instance = undefined,
            transport: ?*runtime.Instance = null,
            jitterBufferTarget: ?DOMHighResTimeStamp = null,
            transform: ?RTCRtpTransform = null,
            _internal: ?*RTCRtpReceiverImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCRtpReceiverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpReceiverImpl.deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCRtpReceiverImpl.get_track(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCRtpReceiverImpl.get_transport(instance);
    }

    pub fn get_jitterBufferTarget(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try RTCRtpReceiverImpl.get_jitterBufferTarget(instance);
    }

    pub fn set_jitterBufferTarget(instance: *runtime.Instance, value: DOMHighResTimeStamp) anyerror!void {
        try RTCRtpReceiverImpl.set_jitterBufferTarget(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!?RTCRtpTransform {
        return try RTCRtpReceiverImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: RTCRtpTransform) anyerror!void {
        try RTCRtpReceiverImpl.set_transform(instance, value);
    }

    pub fn call_getContributingSources(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCRtpReceiverImpl.call_getContributingSources(instance);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance, kind: DOMString) anyerror!?RTCRtpCapabilities {
        
        return try RTCRtpReceiverImpl.call_getCapabilities(instance, kind);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCRtpReceiverImpl.call_getStats(instance);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!RTCRtpReceiveParameters {
        return try RTCRtpReceiverImpl.call_getParameters(instance);
    }

    pub fn call_getSynchronizationSources(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCRtpReceiverImpl.call_getSynchronizationSources(instance);
    }

};

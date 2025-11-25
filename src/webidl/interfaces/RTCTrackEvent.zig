//! Generated from: webrtc.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCTrackEventImpl = @import("impls").RTCTrackEvent;
const Event = @import("interfaces").Event;
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;
const MediaStream = @import("interfaces").MediaStream;
const EventTarget = @import("interfaces").EventTarget;
const RTCTrackEventInit = @import("dictionaries").RTCTrackEventInit;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;
const RTCRtpTransceiver = @import("interfaces").RTCRtpTransceiver;

pub const RTCTrackEvent = struct {
    pub const Meta = struct {
        pub const name = "RTCTrackEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "receiver", "get_receiver", null },
            .{ "track", "get_track", null },
            .{ "streams", "get_streams", null },
            .{ "transceiver", "get_transceiver", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "receiver", "get_receiver", null },
            .{ "track", "get_track", null },
            .{ "streams", "get_streams", null },
            .{ "transceiver", "get_transceiver", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            receiver: *runtime.Instance = undefined,
            track: *runtime.Instance = undefined,
            streams: runtime.FrozenArray(MediaStream) = undefined,
            transceiver: *runtime.Instance = undefined,
            cached_streams: ?runtime.FrozenArray(MediaStream) = null,
            _internal: ?*RTCTrackEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_receiver = &get_receiver,
        .get_streams = &get_streams,
        .get_track = &get_track,
        .get_transceiver = &get_transceiver,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCTrackEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCTrackEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: RTCTrackEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCTrackEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_receiver(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCTrackEventImpl.get_receiver(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCTrackEventImpl.get_track(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_streams(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_streams) |cached| {
            return cached;
        }
        const value = try RTCTrackEventImpl.get_streams(instance);
        state.own.cached_streams = value;
        return value;
    }

    pub fn get_transceiver(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCTrackEventImpl.get_transceiver(instance);
    }

};

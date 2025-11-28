//! Generated from: webrtc.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpTransceiverImpl = @import("impls").RTCRtpTransceiver;
const RTCRtpCodec = @import("dictionaries").RTCRtpCodec;
const RTCRtpSender = @import("interfaces").RTCRtpSender;
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;
const RTCRtpTransceiverDirection = @import("enums").RTCRtpTransceiverDirection;
const DOMString = @import("typedefs").DOMString;

pub const RTCRtpTransceiver = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpTransceiver";
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
            .{ "mid", "get_mid", null },
            .{ "sender", "get_sender", null },
            .{ "receiver", "get_receiver", null },
            .{ "direction", "get_direction", "set_direction" },
            .{ "currentDirection", "get_currentDirection", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "stop", "call_stop", 0 },
            .{ "setCodecPreferences", "call_setCodecPreferences", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "stop",
            "setCodecPreferences",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mid", "get_mid", null },
            .{ "sender", "get_sender", null },
            .{ "receiver", "get_receiver", null },
            .{ "direction", "get_direction", "set_direction" },
            .{ "currentDirection", "get_currentDirection", null },
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
            mid: ?runtime.DOMString = null,
            sender: *runtime.Instance = undefined,
            receiver: *runtime.Instance = undefined,
            direction: RTCRtpTransceiverDirection = undefined,
            currentDirection: ?RTCRtpTransceiverDirection = null,
            cached_sender: ?*runtime.Instance = null,
            cached_receiver: ?*runtime.Instance = null,
            _internal: ?*RTCRtpTransceiverImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentDirection = &get_currentDirection,
        .get_direction = &get_direction,
        .get_mid = &get_mid,
        .get_receiver = &get_receiver,
        .get_sender = &get_sender,

        .set_direction = &set_direction,

        .call_setCodecPreferences = &call_setCodecPreferences,
        .call_stop = &call_stop,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCRtpTransceiverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpTransceiverImpl.deinit(instance);
    }

    pub fn get_mid(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCRtpTransceiverImpl.get_mid(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_sender(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_sender) |cached| {
            return cached;
        }
        const value = try RTCRtpTransceiverImpl.get_sender(instance);
        state.own.cached_sender = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_receiver(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_receiver) |cached| {
            return cached;
        }
        const value = try RTCRtpTransceiverImpl.get_receiver(instance);
        state.own.cached_receiver = value;
        return value;
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!RTCRtpTransceiverDirection {
        return try RTCRtpTransceiverImpl.get_direction(instance);
    }

    pub fn set_direction(instance: *runtime.Instance, value: RTCRtpTransceiverDirection) anyerror!void {
        try RTCRtpTransceiverImpl.set_direction(instance, value);
    }

    pub fn get_currentDirection(instance: *runtime.Instance) anyerror!?RTCRtpTransceiverDirection {
        return try RTCRtpTransceiverImpl.get_currentDirection(instance);
    }

    pub fn call_setCodecPreferences(instance: *runtime.Instance, codecs: *const anyopaque) anyerror!void {
        
        return try RTCRtpTransceiverImpl.call_setCodecPreferences(instance, codecs);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try RTCRtpTransceiverImpl.call_stop(instance);
    }

};

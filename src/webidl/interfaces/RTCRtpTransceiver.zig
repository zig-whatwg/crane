//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpTransceiverImpl = @import("impls").RTCRtpTransceiver;
const RTCRtpSender = @import("interfaces").RTCRtpSender;
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;
const RTCRtpTransceiverDirection = @import("enums").RTCRtpTransceiverDirection;
const DOMString = @import("typedefs").DOMString;

pub const RTCRtpTransceiver = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpTransceiver";
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
            mid: ?runtime.DOMString = null,
            sender: RTCRtpSender = undefined,
            receiver: RTCRtpReceiver = undefined,
            direction: RTCRtpTransceiverDirection = undefined,
            currentDirection: ?RTCRtpTransceiverDirection = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCRtpTransceiver, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentDirection = &get_currentDirection,
        .get_direction = &get_direction,
        .get_mid = &get_mid,
        .get_receiver = &get_receiver,
        .get_sender = &get_sender,

        .set_direction = &set_direction,

        .call_setCodecPreferences = &call_setCodecPreferences,
        .call_stop = &call_stop,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RTCRtpTransceiverImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpTransceiverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_mid(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpTransceiverImpl.get_mid(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_sender(instance: *runtime.Instance) anyerror!RTCRtpSender {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_sender) |cached| {
            return cached;
        }
        const value = try RTCRtpTransceiverImpl.get_sender(instance);
        state.cached_sender = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_receiver(instance: *runtime.Instance) anyerror!RTCRtpReceiver {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_receiver) |cached| {
            return cached;
        }
        const value = try RTCRtpTransceiverImpl.get_receiver(instance);
        state.cached_receiver = value;
        return value;
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!RTCRtpTransceiverDirection {
        return try RTCRtpTransceiverImpl.get_direction(instance);
    }

    pub fn set_direction(instance: *runtime.Instance, value: RTCRtpTransceiverDirection) anyerror!void {
        try RTCRtpTransceiverImpl.set_direction(instance, value);
    }

    pub fn get_currentDirection(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpTransceiverImpl.get_currentDirection(instance);
    }

    pub fn call_setCodecPreferences(instance: *runtime.Instance, codecs: anyopaque) anyerror!void {
        
        return try RTCRtpTransceiverImpl.call_setCodecPreferences(instance, codecs);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try RTCRtpTransceiverImpl.call_stop(instance);
    }

};

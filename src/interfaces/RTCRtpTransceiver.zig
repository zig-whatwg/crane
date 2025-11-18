//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpTransceiverImpl = @import("../impls/RTCRtpTransceiver.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        RTCRtpTransceiverImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCRtpTransceiverImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_mid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpTransceiverImpl.get_mid(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_sender(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_sender) |cached| {
            return cached;
        }
        const value = RTCRtpTransceiverImpl.get_sender(state);
        state.cached_sender = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_receiver(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_receiver) |cached| {
            return cached;
        }
        const value = RTCRtpTransceiverImpl.get_receiver(state);
        state.cached_receiver = value;
        return value;
    }

    pub fn get_direction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpTransceiverImpl.get_direction(state);
    }

    pub fn set_direction(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCRtpTransceiverImpl.set_direction(state, value);
    }

    pub fn get_currentDirection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpTransceiverImpl.get_currentDirection(state);
    }

    pub fn call_setCodecPreferences(instance: *runtime.Instance, codecs: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpTransceiverImpl.call_setCodecPreferences(state, codecs);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpTransceiverImpl.call_stop(state);
    }

};

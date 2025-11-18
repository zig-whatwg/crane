//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCTrackEventImpl = @import("impls").RTCTrackEvent;
const Event = @import("interfaces").Event;
const RTCRtpTransceiver = @import("interfaces").RTCRtpTransceiver;
const RTCTrackEventInit = @import("dictionaries").RTCTrackEventInit;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;
const FrozenArray<MediaStream> = @import("interfaces").FrozenArray<MediaStream>;

pub const RTCTrackEvent = struct {
    pub const Meta = struct {
        pub const name = "RTCTrackEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            receiver: RTCRtpReceiver = undefined,
            track: MediaStreamTrack = undefined,
            streams: FrozenArray<MediaStream> = undefined,
            transceiver: RTCRtpTransceiver = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCTrackEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_receiver = &get_receiver,
        .get_returnValue = &get_returnValue,
        .get_srcElement = &get_srcElement,
        .get_streams = &get_streams,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_track = &get_track,
        .get_transceiver = &get_transceiver,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RTCTrackEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCTrackEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, eventInitDict: RTCTrackEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RTCTrackEventImpl.constructor(instance, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCTrackEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCTrackEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCTrackEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCTrackEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try RTCTrackEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try RTCTrackEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try RTCTrackEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try RTCTrackEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try RTCTrackEventImpl.get_timeStamp(instance);
    }

    pub fn get_receiver(instance: *runtime.Instance) anyerror!RTCRtpReceiver {
        return try RTCTrackEventImpl.get_receiver(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!MediaStreamTrack {
        return try RTCTrackEventImpl.get_track(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_streams(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_streams) |cached| {
            return cached;
        }
        const value = try RTCTrackEventImpl.get_streams(instance);
        state.cached_streams = value;
        return value;
    }

    pub fn get_transceiver(instance: *runtime.Instance) anyerror!RTCRtpTransceiver {
        return try RTCTrackEventImpl.get_transceiver(instance);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try RTCTrackEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try RTCTrackEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCTrackEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try RTCTrackEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try RTCTrackEventImpl.call_preventDefault(instance);
    }

};

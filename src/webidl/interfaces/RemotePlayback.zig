//! Generated from: remote-playback.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RemotePlaybackImpl = @import("impls").RemotePlayback;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const RemotePlaybackState = @import("enums").RemotePlaybackState;
const RemotePlaybackAvailabilityCallback = @import("callbacks").RemotePlaybackAvailabilityCallback;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const RemotePlayback = struct {
    pub const Meta = struct {
        pub const name = "RemotePlayback";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            state: RemotePlaybackState = undefined,
            onconnecting: EventHandler = undefined,
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RemotePlayback, .{
        .deinit_fn = &deinit_wrapper,

        .get_onconnect = &get_onconnect,
        .get_onconnecting = &get_onconnecting,
        .get_ondisconnect = &get_ondisconnect,
        .get_state = &get_state,

        .set_onconnect = &set_onconnect,
        .set_onconnecting = &set_onconnecting,
        .set_ondisconnect = &set_ondisconnect,

        .call_addEventListener = &call_addEventListener,
        .call_cancelWatchAvailability = &call_cancelWatchAvailability,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_prompt = &call_prompt,
        .call_removeEventListener = &call_removeEventListener,
        .call_watchAvailability = &call_watchAvailability,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return RemotePlaybackImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RemotePlaybackImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RemotePlaybackState {
        return try RemotePlaybackImpl.get_state(instance);
    }

    pub fn get_onconnecting(instance: *runtime.Instance) anyerror!EventHandler {
        return try RemotePlaybackImpl.get_onconnecting(instance);
    }

    pub fn set_onconnecting(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RemotePlaybackImpl.set_onconnecting(instance, value);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try RemotePlaybackImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RemotePlaybackImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try RemotePlaybackImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RemotePlaybackImpl.set_ondisconnect(instance, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try RemotePlaybackImpl.call_removeEventListener(instance, @"type", callback, options);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RemotePlaybackImpl.call_when(instance, @"type", options);
    }

    pub fn call_watchAvailability(instance: *runtime.Instance, callback: RemotePlaybackAvailabilityCallback) anyerror!anyopaque {
        
        return try RemotePlaybackImpl.call_watchAvailability(instance, callback);
    }

    pub fn call_prompt(instance: *runtime.Instance) anyerror!anyopaque {
        return try RemotePlaybackImpl.call_prompt(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RemotePlaybackImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_cancelWatchAvailability(instance: *runtime.Instance, id: i32) anyerror!anyopaque {
        
        return try RemotePlaybackImpl.call_cancelWatchAvailability(instance, id);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try RemotePlaybackImpl.call_addEventListener(instance, @"type", callback, options);
    }

};

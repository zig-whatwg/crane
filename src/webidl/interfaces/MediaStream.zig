//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaStreamImpl = @import("impls").MediaStream;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaStream = struct {
    pub const Meta = struct {
        pub const name = "MediaStream";
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
            id: runtime.DOMString = undefined,
            active: bool = undefined,
            onaddtrack: EventHandler = undefined,
            onremovetrack: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_active = &get_active,
        .get_id = &get_id,
        .get_onaddtrack = &get_onaddtrack,
        .get_onremovetrack = &get_onremovetrack,

        .set_onaddtrack = &set_onaddtrack,
        .set_onremovetrack = &set_onremovetrack,

        .call_addEventListener = &call_addEventListener,
        .call_addTrack = &call_addTrack,
        .call_clone = &call_clone,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAudioTracks = &call_getAudioTracks,
        .call_getTrackById = &call_getTrackById,
        .call_getTracks = &call_getTracks,
        .call_getVideoTracks = &call_getVideoTracks,
        .call_removeEventListener = &call_removeEventListener,
        .call_removeTrack = &call_removeTrack,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MediaStreamImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor()
        no_params: void,
        /// constructor(stream)
        MediaStream: MediaStream,
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, args: ConstructorArgs) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        switch (args) {
            .no_params => try MediaStreamImpl.constructor(instance),
            .MediaStream => |arg| try MediaStreamImpl.constructor(instance, arg),
        }
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaStreamImpl.get_id(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try MediaStreamImpl.get_active(instance);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaStreamImpl.get_onaddtrack(instance);
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaStreamImpl.set_onaddtrack(instance, value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaStreamImpl.get_onremovetrack(instance);
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaStreamImpl.set_onremovetrack(instance, value);
    }

    pub fn call_getAudioTracks(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaStreamImpl.call_getAudioTracks(instance);
    }

    pub fn call_getVideoTracks(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaStreamImpl.call_getVideoTracks(instance);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MediaStreamImpl.call_when(instance, @"type", options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!MediaStream {
        return try MediaStreamImpl.call_clone(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MediaStreamImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, trackId: DOMString) anyerror!MediaStreamTrack {
        
        return try MediaStreamImpl.call_getTrackById(instance, trackId);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: MediaStreamTrack) anyerror!void {
        
        return try MediaStreamImpl.call_addTrack(instance, track);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, track: MediaStreamTrack) anyerror!void {
        
        return try MediaStreamImpl.call_removeTrack(instance, track);
    }

    pub fn call_getTracks(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaStreamImpl.call_getTracks(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try MediaStreamImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try MediaStreamImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

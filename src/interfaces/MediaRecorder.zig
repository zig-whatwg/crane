//! Generated from: mediastream-recording.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaRecorderImpl = @import("../impls/MediaRecorder.zig");
const EventTarget = @import("EventTarget.zig");

pub const MediaRecorder = struct {
    pub const Meta = struct {
        pub const name = "MediaRecorder";
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
            stream: MediaStream = undefined,
            mimeType: runtime.DOMString = undefined,
            state: RecordingState = undefined,
            onstart: EventHandler = undefined,
            onstop: EventHandler = undefined,
            ondataavailable: EventHandler = undefined,
            onpause: EventHandler = undefined,
            onresume: EventHandler = undefined,
            onerror: EventHandler = undefined,
            videoBitsPerSecond: u32 = undefined,
            audioBitsPerSecond: u32 = undefined,
            audioBitrateMode: BitrateMode = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaRecorder, .{
        .deinit_fn = &deinit_wrapper,

        .get_audioBitrateMode = &get_audioBitrateMode,
        .get_audioBitsPerSecond = &get_audioBitsPerSecond,
        .get_mimeType = &get_mimeType,
        .get_ondataavailable = &get_ondataavailable,
        .get_onerror = &get_onerror,
        .get_onpause = &get_onpause,
        .get_onresume = &get_onresume,
        .get_onstart = &get_onstart,
        .get_onstop = &get_onstop,
        .get_state = &get_state,
        .get_stream = &get_stream,
        .get_videoBitsPerSecond = &get_videoBitsPerSecond,

        .set_ondataavailable = &set_ondataavailable,
        .set_onerror = &set_onerror,
        .set_onpause = &set_onpause,
        .set_onresume = &set_onresume,
        .set_onstart = &set_onstart,
        .set_onstop = &set_onstop,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_isTypeSupported = &call_isTypeSupported,
        .call_pause = &call_pause,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestData = &call_requestData,
        .call_resume = &call_resume,
        .call_start = &call_start,
        .call_stop = &call_stop,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaRecorderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaRecorderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MediaRecorderImpl.constructor(state, stream, options);
        
        return instance;
    }

    pub fn get_stream(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_stream(state);
    }

    pub fn get_mimeType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_mimeType(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_state(state);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_onstart(state);
    }

    pub fn set_onstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaRecorderImpl.set_onstart(state, value);
    }

    pub fn get_onstop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_onstop(state);
    }

    pub fn set_onstop(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaRecorderImpl.set_onstop(state, value);
    }

    pub fn get_ondataavailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_ondataavailable(state);
    }

    pub fn set_ondataavailable(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaRecorderImpl.set_ondataavailable(state, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_onpause(state);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaRecorderImpl.set_onpause(state, value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_onresume(state);
    }

    pub fn set_onresume(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaRecorderImpl.set_onresume(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaRecorderImpl.set_onerror(state, value);
    }

    pub fn get_videoBitsPerSecond(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_videoBitsPerSecond(state);
    }

    pub fn get_audioBitsPerSecond(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_audioBitsPerSecond(state);
    }

    pub fn get_audioBitrateMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.get_audioBitrateMode(state);
    }

    pub fn call_resume(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.call_resume(state);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.call_stop(state);
    }

    pub fn call_requestData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.call_requestData(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaRecorderImpl.call_when(state, type_, options);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, type_: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return MediaRecorderImpl.call_isTypeSupported(state, type_);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaRecorderImpl.call_dispatchEvent(state, event);
    }

    pub fn call_pause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaRecorderImpl.call_pause(state);
    }

    pub fn call_start(instance: *runtime.Instance, timeslice: u32) anyopaque {
        const state = instance.getState(State);
        
        return MediaRecorderImpl.call_start(state, timeslice);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaRecorderImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaRecorderImpl.call_removeEventListener(state, type_, callback, options);
    }

};

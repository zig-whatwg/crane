//! Generated from: mediastream-recording.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaRecorderImpl = @import("impls").MediaRecorder;
const EventTarget = @import("interfaces").EventTarget;
const RecordingState = @import("enums").RecordingState;
const EventHandler = @import("typedefs").EventHandler;
const BitrateMode = @import("enums").BitrateMode;
const MediaStream = @import("interfaces").MediaStream;
const MediaRecorderOptions = @import("dictionaries").MediaRecorderOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        MediaRecorderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaRecorderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: MediaStream, options: MediaRecorderOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MediaRecorderImpl.constructor(instance, stream, options);
        
        return instance;
    }

    pub fn get_stream(instance: *runtime.Instance) anyerror!MediaStream {
        return try MediaRecorderImpl.get_stream(instance);
    }

    pub fn get_mimeType(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaRecorderImpl.get_mimeType(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RecordingState {
        return try MediaRecorderImpl.get_state(instance);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaRecorderImpl.get_onstart(instance);
    }

    pub fn set_onstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaRecorderImpl.set_onstart(instance, value);
    }

    pub fn get_onstop(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaRecorderImpl.get_onstop(instance);
    }

    pub fn set_onstop(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaRecorderImpl.set_onstop(instance, value);
    }

    pub fn get_ondataavailable(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaRecorderImpl.get_ondataavailable(instance);
    }

    pub fn set_ondataavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaRecorderImpl.set_ondataavailable(instance, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaRecorderImpl.get_onpause(instance);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaRecorderImpl.set_onpause(instance, value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaRecorderImpl.get_onresume(instance);
    }

    pub fn set_onresume(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaRecorderImpl.set_onresume(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaRecorderImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaRecorderImpl.set_onerror(instance, value);
    }

    pub fn get_videoBitsPerSecond(instance: *runtime.Instance) anyerror!u32 {
        return try MediaRecorderImpl.get_videoBitsPerSecond(instance);
    }

    pub fn get_audioBitsPerSecond(instance: *runtime.Instance) anyerror!u32 {
        return try MediaRecorderImpl.get_audioBitsPerSecond(instance);
    }

    pub fn get_audioBitrateMode(instance: *runtime.Instance) anyerror!BitrateMode {
        return try MediaRecorderImpl.get_audioBitrateMode(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_resume(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_stop(instance);
    }

    pub fn call_requestData(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_requestData(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MediaRecorderImpl.call_when(instance, type_, options);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, type_: DOMString) anyerror!bool {
        
        return try MediaRecorderImpl.call_isTypeSupported(instance, type_);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MediaRecorderImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_pause(instance);
    }

    pub fn call_start(instance: *runtime.Instance, timeslice: u32) anyerror!void {
        
        return try MediaRecorderImpl.call_start(instance, timeslice);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaRecorderImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaRecorderImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

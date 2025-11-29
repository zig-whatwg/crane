//! Generated from: mediastream-recording.idl
//! Generated at: 2025-11-29T05:01:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaRecorderImpl = @import("impls").MediaRecorder;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BitrateMode = @import("enums").BitrateMode;
const MediaRecorderOptions = @import("dictionaries").MediaRecorderOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const RecordingState = @import("enums").RecordingState;
const MediaStream = @import("interfaces").MediaStream;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaRecorder = struct {
    pub const Meta = struct {
        pub const name = "MediaRecorder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "stream", "get_stream", null },
            .{ "mimeType", "get_mimeType", null },
            .{ "state", "get_state", null },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onstop", "get_onstop", "set_onstop" },
            .{ "ondataavailable", "get_ondataavailable", "set_ondataavailable" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "videoBitsPerSecond", "get_videoBitsPerSecond", null },
            .{ "audioBitsPerSecond", "get_audioBitsPerSecond", null },
            .{ "audioBitrateMode", "get_audioBitrateMode", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "pause", "call_pause", 0 },
            .{ "resume", "call_resume", 0 },
            .{ "requestData", "call_requestData", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isTypeSupported", "call_isTypeSupported", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
            "pause",
            "resume",
            "requestData",
            "isTypeSupported",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "stream", "get_stream", null },
            .{ "mimeType", "get_mimeType", null },
            .{ "state", "get_state", null },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onstop", "get_onstop", "set_onstop" },
            .{ "ondataavailable", "get_ondataavailable", "set_ondataavailable" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "videoBitsPerSecond", "get_videoBitsPerSecond", null },
            .{ "audioBitsPerSecond", "get_audioBitsPerSecond", null },
            .{ "audioBitrateMode", "get_audioBitrateMode", null },
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
            stream: *runtime.Instance = undefined,
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
            _internal: ?*MediaRecorderImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .call_isTypeSupported = &call_isTypeSupported,
        .call_pause = &call_pause,
        .call_requestData = &call_requestData,
        .call_resume = &call_resume,
        .call_start = &call_start,
        .call_stop = &call_stop,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaRecorderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaRecorderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, stream: *runtime.Instance, options: webidl.Opt(MediaRecorderOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaRecorderImpl.call_constructor(allocator, ctx, stream, options);
    }

    pub fn get_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_stop(instance);
    }

    pub fn call_requestData(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_requestData(instance);
    }

    pub fn call_start(instance: *runtime.Instance, timeslice: webidl.Opt(u32)) anyerror!void {
        
        return try MediaRecorderImpl.call_start(instance, timeslice);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, @"type": DOMString) anyerror!bool {
        
        return try MediaRecorderImpl.call_isTypeSupported(instance, @"type");
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_resume(instance);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_pause(instance);
    }

};

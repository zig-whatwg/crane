//! Generated from: mediastream-recording.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaRecorderImpl = @import("impls").MediaRecorder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BitrateMode = @import("enums").BitrateMode;
const MediaRecorderOptions = @import("dictionaries").MediaRecorderOptions;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const RecordingState = @import("enums").RecordingState;
const MediaStream = @import("MediaStream.zig").MediaStream;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
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
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
            "pause",
            "resume",
            "requestData",
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isTypeSupported", "call_static_isTypeSupported", 1 },
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            stream: *runtime.Instance = undefined,
            mimeType: typedefs.DOMString = undefined,
            state: enums.RecordingState = undefined,
            onstart: typedefs.EventHandler = undefined,
            onstop: typedefs.EventHandler = undefined,
            ondataavailable: typedefs.EventHandler = undefined,
            onpause: typedefs.EventHandler = undefined,
            onresume: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            videoBitsPerSecond: u32 = undefined,
            audioBitsPerSecond: u32 = undefined,
            audioBitrateMode: enums.BitrateMode = undefined,
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

        .call_pause = &call_pause,
        .call_requestData = &call_requestData,
        .call_resume = &call_resume,
        .call_start = &call_start,
        .call_stop = &call_stop,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaRecorderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaRecorderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaRecorderImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance, options: webidl.Opt(MediaRecorderOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaRecorderImpl.call_constructor(ctx, stream, options);
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

    pub fn call_start(instance: *runtime.Instance, timeslice: webidl.Opt(u32)) anyerror!void {
        
        return try MediaRecorderImpl.call_start(instance, timeslice);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_pause(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_resume(instance);
    }

    pub fn call_static_isTypeSupported(instance: *runtime.Instance, @"type": DOMString) anyerror!bool {
        
        return try MediaRecorderImpl.call_static_isTypeSupported(instance, @"type");
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_stop(instance);
    }

    pub fn call_requestData(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_requestData(instance);
    }

};

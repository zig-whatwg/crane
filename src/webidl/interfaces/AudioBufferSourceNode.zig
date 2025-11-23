//! Generated from: webaudio.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioBufferSourceNodeImpl = @import("impls").AudioBufferSourceNode;
const AudioScheduledSourceNode = @import("interfaces").AudioScheduledSourceNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const EventHandler = @import("typedefs").EventHandler;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioBufferSourceOptions = @import("dictionaries").AudioBufferSourceOptions;
const AudioParam = @import("interfaces").AudioParam;
const AudioBuffer = @import("interfaces").AudioBuffer;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const AudioNode = @import("interfaces").AudioNode;
const DOMString = @import("typedefs").DOMString;

pub const AudioBufferSourceNode = struct {
    pub const Meta = struct {
        pub const name = "AudioBufferSourceNode";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioScheduledSourceNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "buffer", "get_buffer", "set_buffer" },
            .{ "playbackRate", "get_playbackRate", null },
            .{ "detune", "get_detune", null },
            .{ "loop", "get_loop", "set_loop" },
            .{ "loopStart", "get_loopStart", "set_loopStart" },
            .{ "loopEnd", "get_loopEnd", "set_loopEnd" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "stop",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "buffer", "get_buffer", "set_buffer" },
            .{ "playbackRate", "get_playbackRate", null },
            .{ "detune", "get_detune", null },
            .{ "loop", "get_loop", "set_loop" },
            .{ "loopStart", "get_loopStart", "set_loopStart" },
            .{ "loopEnd", "get_loopEnd", "set_loopEnd" },
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
            buffer: ?*runtime.Instance = null,
            playbackRate: *runtime.Instance = undefined,
            detune: *runtime.Instance = undefined,
            loop: bool = undefined,
            loopStart: f64 = undefined,
            loopEnd: f64 = undefined,
            _internal: ?*AudioBufferSourceNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_buffer = &get_buffer,
        .get_detune = &get_detune,
        .get_loop = &get_loop,
        .get_loopEnd = &get_loopEnd,
        .get_loopStart = &get_loopStart,
        .get_playbackRate = &get_playbackRate,

        .set_buffer = &set_buffer,
        .set_loop = &set_loop,
        .set_loopEnd = &set_loopEnd,
        .set_loopStart = &set_loopStart,

        .call_start = &call_start,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioBufferSourceNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioBufferSourceNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: AudioBufferSourceOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioBufferSourceNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn get_buffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioBufferSourceNodeImpl.get_buffer(instance);
    }

    pub fn set_buffer(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try AudioBufferSourceNodeImpl.set_buffer(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioBufferSourceNodeImpl.get_playbackRate(instance);
    }

    pub fn get_detune(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioBufferSourceNodeImpl.get_detune(instance);
    }

    pub fn get_loop(instance: *runtime.Instance) anyerror!bool {
        return try AudioBufferSourceNodeImpl.get_loop(instance);
    }

    pub fn set_loop(instance: *runtime.Instance, value: bool) anyerror!void {
        try AudioBufferSourceNodeImpl.set_loop(instance, value);
    }

    pub fn get_loopStart(instance: *runtime.Instance) anyerror!f64 {
        return try AudioBufferSourceNodeImpl.get_loopStart(instance);
    }

    pub fn set_loopStart(instance: *runtime.Instance, value: f64) anyerror!void {
        try AudioBufferSourceNodeImpl.set_loopStart(instance, value);
    }

    pub fn get_loopEnd(instance: *runtime.Instance) anyerror!f64 {
        return try AudioBufferSourceNodeImpl.get_loopEnd(instance);
    }

    pub fn set_loopEnd(instance: *runtime.Instance, value: f64) anyerror!void {
        try AudioBufferSourceNodeImpl.set_loopEnd(instance, value);
    }

    pub fn call_start(instance: *runtime.Instance, when: f64, offset: f64, duration: f64) anyerror!void {
        
        return try AudioBufferSourceNodeImpl.call_start(instance, when, offset, duration);
    }

};

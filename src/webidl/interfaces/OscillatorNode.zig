//! Generated from: webaudio.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OscillatorNodeImpl = @import("impls").OscillatorNode;
const AudioScheduledSourceNode = @import("interfaces").AudioScheduledSourceNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const OscillatorOptions = @import("dictionaries").OscillatorOptions;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const PeriodicWave = @import("interfaces").PeriodicWave;
const AudioParam = @import("interfaces").AudioParam;
const OscillatorType = @import("enums").OscillatorType;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const AudioNode = @import("interfaces").AudioNode;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const OscillatorNode = struct {
    pub const Meta = struct {
        pub const name = "OscillatorNode";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "type", "get_type", "set_type" },
            .{ "frequency", "get_frequency", null },
            .{ "detune", "get_detune", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPeriodicWave", "call_setPeriodicWave", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPeriodicWave",
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
            "start",
            "stop",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "frequency", "get_frequency", null },
            .{ "detune", "get_detune", null },
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
            @"type": OscillatorType = undefined,
            frequency: *runtime.Instance = undefined,
            detune: *runtime.Instance = undefined,
            _internal: ?*OscillatorNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_detune = &get_detune,
        .get_frequency = &get_frequency,
        .get_type = &get_type,

        .set_type = &set_type,

        .call_setPeriodicWave = &call_setPeriodicWave,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OscillatorNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OscillatorNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: OscillatorOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try OscillatorNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!OscillatorType {
        return try OscillatorNodeImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: OscillatorType) anyerror!void {
        try OscillatorNodeImpl.set_type(instance, value);
    }

    pub fn get_frequency(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OscillatorNodeImpl.get_frequency(instance);
    }

    pub fn get_detune(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OscillatorNodeImpl.get_detune(instance);
    }

    pub fn call_setPeriodicWave(instance: *runtime.Instance, periodicWave: *runtime.Instance) anyerror!void {
        
        return try OscillatorNodeImpl.call_setPeriodicWave(instance, periodicWave);
    }

};

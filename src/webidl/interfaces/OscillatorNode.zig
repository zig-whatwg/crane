//! Generated from: webaudio.idl
//! Generated at: 2025-11-19T20:02:01Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioScheduledSourceNode;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            @"type": OscillatorType = undefined,
            frequency: AudioParam = undefined,
            detune: AudioParam = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(OscillatorNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_detune = &get_detune,
        .get_frequency = &get_frequency,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,
        .get_onended = &get_onended,
        .get_type = &get_type,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,
        .set_onended = &set_onended,
        .set_type = &set_type,

        .call_addEventListener = &call_addEventListener,
        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_setPeriodicWave = &call_setPeriodicWave,
        .call_start = &call_start,
        .call_stop = &call_stop,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return OscillatorNodeImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OscillatorNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: BaseAudioContext, options: OscillatorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try OscillatorNodeImpl.constructor(instance, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!BaseAudioContext {
        return try OscillatorNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try OscillatorNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try OscillatorNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try OscillatorNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try OscillatorNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try OscillatorNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try OscillatorNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try OscillatorNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try OscillatorNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try OscillatorNodeImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try OscillatorNodeImpl.set_onended(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!OscillatorType {
        return try OscillatorNodeImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: OscillatorType) anyerror!void {
        try OscillatorNodeImpl.set_type(instance, value);
    }

    pub fn get_frequency(instance: *runtime.Instance) anyerror!AudioParam {
        return try OscillatorNodeImpl.get_frequency(instance);
    }

    pub fn get_detune(instance: *runtime.Instance) anyerror!AudioParam {
        return try OscillatorNodeImpl.get_detune(instance);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try OscillatorNodeImpl.call_removeEventListener(instance, @"type", callback, options);
    }

    pub fn call_stop(instance: *runtime.Instance, when: f64) anyerror!void {
        
        return try OscillatorNodeImpl.call_stop(instance, when);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try OscillatorNodeImpl.call_when(instance, @"type", options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try OscillatorNodeImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try OscillatorNodeImpl.call_disconnect(instance);
    }

    pub fn call_start(instance: *runtime.Instance, when: f64) anyerror!void {
        
        return try OscillatorNodeImpl.call_start(instance, when);
    }

    pub fn call_setPeriodicWave(instance: *runtime.Instance, periodicWave: PeriodicWave) anyerror!void {
        
        return try OscillatorNodeImpl.call_setPeriodicWave(instance, periodicWave);
    }

    pub fn call_connect(instance: *runtime.Instance, destinationNode: AudioNode, output: u32, input: u32) anyerror!AudioNode {
        
        return try OscillatorNodeImpl.call_connect(instance, destinationNode, output, input);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try OscillatorNodeImpl.call_addEventListener(instance, @"type", callback, options);
    }

};

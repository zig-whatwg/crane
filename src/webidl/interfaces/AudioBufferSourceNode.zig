//! Generated from: webaudio.idl
//! Generated at: 2025-11-19T20:02:01Z
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
            buffer: ?AudioBuffer = null,
            playbackRate: AudioParam = undefined,
            detune: AudioParam = undefined,
            loop: bool = undefined,
            loopStart: f64 = undefined,
            loopEnd: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioBufferSourceNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_buffer = &get_buffer,
        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_detune = &get_detune,
        .get_loop = &get_loop,
        .get_loopEnd = &get_loopEnd,
        .get_loopStart = &get_loopStart,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,
        .get_onended = &get_onended,
        .get_playbackRate = &get_playbackRate,

        .set_buffer = &set_buffer,
        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,
        .set_loop = &set_loop,
        .set_loopEnd = &set_loopEnd,
        .set_loopStart = &set_loopStart,
        .set_onended = &set_onended,

        .call_addEventListener = &call_addEventListener,
        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
        .call_stop = &call_stop,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return AudioBufferSourceNodeImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioBufferSourceNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: BaseAudioContext, options: AudioBufferSourceOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AudioBufferSourceNodeImpl.constructor(instance, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!BaseAudioContext {
        return try AudioBufferSourceNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferSourceNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferSourceNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferSourceNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try AudioBufferSourceNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try AudioBufferSourceNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try AudioBufferSourceNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try AudioBufferSourceNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try AudioBufferSourceNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioBufferSourceNodeImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioBufferSourceNodeImpl.set_onended(instance, value);
    }

    pub fn get_buffer(instance: *runtime.Instance) anyerror!AudioBuffer {
        return try AudioBufferSourceNodeImpl.get_buffer(instance);
    }

    pub fn set_buffer(instance: *runtime.Instance, value: AudioBuffer) anyerror!void {
        try AudioBufferSourceNodeImpl.set_buffer(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!AudioParam {
        return try AudioBufferSourceNodeImpl.get_playbackRate(instance);
    }

    pub fn get_detune(instance: *runtime.Instance) anyerror!AudioParam {
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

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try AudioBufferSourceNodeImpl.call_removeEventListener(instance, @"type", callback, options);
    }

    pub fn call_stop(instance: *runtime.Instance, when: f64) anyerror!void {
        
        return try AudioBufferSourceNodeImpl.call_stop(instance, when);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AudioBufferSourceNodeImpl.call_when(instance, @"type", options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AudioBufferSourceNodeImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try AudioBufferSourceNodeImpl.call_disconnect(instance);
    }

    pub fn call_start(instance: *runtime.Instance, when: f64) anyerror!void {
        
        return try AudioBufferSourceNodeImpl.call_start(instance, when);
    }

    pub fn call_connect(instance: *runtime.Instance, destinationNode: AudioNode, output: u32, input: u32) anyerror!AudioNode {
        
        return try AudioBufferSourceNodeImpl.call_connect(instance, destinationNode, output, input);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try AudioBufferSourceNodeImpl.call_addEventListener(instance, @"type", callback, options);
    }

};

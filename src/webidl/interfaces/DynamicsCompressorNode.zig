//! Generated from: webaudio.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DynamicsCompressorNodeImpl = @import("impls").DynamicsCompressorNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const DynamicsCompressorOptions = @import("dictionaries").DynamicsCompressorOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const DynamicsCompressorNode = struct {
    pub const Meta = struct {
        pub const name = "DynamicsCompressorNode";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioNode;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            threshold: AudioParam = undefined,
            knee: AudioParam = undefined,
            ratio: AudioParam = undefined,
            reduction: f32 = undefined,
            attack: AudioParam = undefined,
            release: AudioParam = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DynamicsCompressorNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_attack = &get_attack,
        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_knee = &get_knee,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,
        .get_ratio = &get_ratio,
        .get_reduction = &get_reduction,
        .get_release = &get_release,
        .get_threshold = &get_threshold,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,

        .call_addEventListener = &call_addEventListener,
        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return DynamicsCompressorNodeImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DynamicsCompressorNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: BaseAudioContext, options: DynamicsCompressorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DynamicsCompressorNodeImpl.constructor(instance, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!BaseAudioContext {
        return try DynamicsCompressorNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try DynamicsCompressorNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try DynamicsCompressorNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try DynamicsCompressorNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try DynamicsCompressorNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try DynamicsCompressorNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try DynamicsCompressorNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try DynamicsCompressorNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try DynamicsCompressorNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn get_threshold(instance: *runtime.Instance) anyerror!AudioParam {
        return try DynamicsCompressorNodeImpl.get_threshold(instance);
    }

    pub fn get_knee(instance: *runtime.Instance) anyerror!AudioParam {
        return try DynamicsCompressorNodeImpl.get_knee(instance);
    }

    pub fn get_ratio(instance: *runtime.Instance) anyerror!AudioParam {
        return try DynamicsCompressorNodeImpl.get_ratio(instance);
    }

    pub fn get_reduction(instance: *runtime.Instance) anyerror!f32 {
        return try DynamicsCompressorNodeImpl.get_reduction(instance);
    }

    pub fn get_attack(instance: *runtime.Instance) anyerror!AudioParam {
        return try DynamicsCompressorNodeImpl.get_attack(instance);
    }

    pub fn get_release(instance: *runtime.Instance) anyerror!AudioParam {
        return try DynamicsCompressorNodeImpl.get_release(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try DynamicsCompressorNodeImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_connect(instance: *runtime.Instance, destinationNode: AudioNode, output: u32, input: u32) anyerror!AudioNode {
        
        return try DynamicsCompressorNodeImpl.call_connect(instance, destinationNode, output, input);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try DynamicsCompressorNodeImpl.call_disconnect(instance);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try DynamicsCompressorNodeImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try DynamicsCompressorNodeImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try DynamicsCompressorNodeImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

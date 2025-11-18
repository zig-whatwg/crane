//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioScheduledSourceNodeImpl = @import("impls").AudioScheduledSourceNode;
const AudioNode = @import("interfaces").AudioNode;
const EventHandler = @import("typedefs").EventHandler;

pub const AudioScheduledSourceNode = struct {
    pub const Meta = struct {
        pub const name = "AudioScheduledSourceNode";
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
            onended: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioScheduledSourceNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,
        .get_onended = &get_onended,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AudioScheduledSourceNodeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioScheduledSourceNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!BaseAudioContext {
        return try AudioScheduledSourceNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioScheduledSourceNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try AudioScheduledSourceNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try AudioScheduledSourceNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try AudioScheduledSourceNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try AudioScheduledSourceNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try AudioScheduledSourceNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try AudioScheduledSourceNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try AudioScheduledSourceNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioScheduledSourceNodeImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioScheduledSourceNodeImpl.set_onended(instance, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioScheduledSourceNodeImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_stop(instance: *runtime.Instance, when: f64) anyerror!void {
        
        return try AudioScheduledSourceNodeImpl.call_stop(instance, when);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AudioScheduledSourceNodeImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AudioScheduledSourceNodeImpl.call_dispatchEvent(instance, event);
    }

    /// Arguments for disconnect (WebIDL overloading)
    pub const DisconnectArgs = union(enum) {
        /// disconnect()
        no_params: void,
        /// disconnect(output)
        long: u32,
        /// disconnect(destinationNode)
        AudioNode: AudioNode,
        /// disconnect(destinationNode, output)
        AudioNode_long: struct {
            destinationNode: AudioNode,
            output: u32,
        },
        /// disconnect(destinationNode, output, input)
        AudioNode_long_long: struct {
            destinationNode: AudioNode,
            output: u32,
            input: u32,
        },
        /// disconnect(destinationParam)
        AudioParam: AudioParam,
        /// disconnect(destinationParam, output)
        AudioParam_long: struct {
            destinationParam: AudioParam,
            output: u32,
        },
    };

    pub fn call_disconnect(instance: *runtime.Instance, args: DisconnectArgs) anyerror!void {
        switch (args) {
            .no_params => return try AudioScheduledSourceNodeImpl.no_params(instance),
            .long => |arg| return try AudioScheduledSourceNodeImpl.long(instance, arg),
            .AudioNode => |arg| return try AudioScheduledSourceNodeImpl.AudioNode(instance, arg),
            .AudioNode_long => |a| return try AudioScheduledSourceNodeImpl.AudioNode_long(instance, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return try AudioScheduledSourceNodeImpl.AudioNode_long_long(instance, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return try AudioScheduledSourceNodeImpl.AudioParam(instance, arg),
            .AudioParam_long => |a| return try AudioScheduledSourceNodeImpl.AudioParam_long(instance, a.destinationParam, a.output),
        }
    }

    pub fn call_start(instance: *runtime.Instance, when: f64) anyerror!void {
        
        return try AudioScheduledSourceNodeImpl.call_start(instance, when);
    }

    /// Arguments for connect (WebIDL overloading)
    pub const ConnectArgs = union(enum) {
        /// connect(destinationNode, output, input)
        AudioNode_long_long: struct {
            destinationNode: AudioNode,
            output: u32,
            input: u32,
        },
        /// connect(destinationParam, output)
        AudioParam_long: struct {
            destinationParam: AudioParam,
            output: u32,
        },
    };

    pub fn call_connect(instance: *runtime.Instance, args: ConnectArgs) anyerror!AudioNode {
        switch (args) {
            .AudioNode_long_long => |a| return try AudioScheduledSourceNodeImpl.AudioNode_long_long(instance, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return try AudioScheduledSourceNodeImpl.AudioParam_long(instance, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioScheduledSourceNodeImpl.call_addEventListener(instance, type_, callback, options);
    }

};

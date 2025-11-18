//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GainNodeImpl = @import("impls").GainNode;
const AudioNode = @import("interfaces").AudioNode;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const AudioParam = @import("interfaces").AudioParam;
const GainOptions = @import("dictionaries").GainOptions;

pub const GainNode = struct {
    pub const Meta = struct {
        pub const name = "GainNode";
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
            gain: AudioParam = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GainNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_gain = &get_gain,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GainNodeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GainNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: BaseAudioContext, options: GainOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try GainNodeImpl.constructor(instance, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!BaseAudioContext {
        return try GainNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try GainNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try GainNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try GainNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try GainNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try GainNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try GainNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try GainNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try GainNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn get_gain(instance: *runtime.Instance) anyerror!AudioParam {
        return try GainNodeImpl.get_gain(instance);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try GainNodeImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try GainNodeImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try GainNodeImpl.call_dispatchEvent(instance, event);
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
            .no_params => return try GainNodeImpl.no_params(instance),
            .long => |arg| return try GainNodeImpl.long(instance, arg),
            .AudioNode => |arg| return try GainNodeImpl.AudioNode(instance, arg),
            .AudioNode_long => |a| return try GainNodeImpl.AudioNode_long(instance, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return try GainNodeImpl.AudioNode_long_long(instance, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return try GainNodeImpl.AudioParam(instance, arg),
            .AudioParam_long => |a| return try GainNodeImpl.AudioParam_long(instance, a.destinationParam, a.output),
        }
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
            .AudioNode_long_long => |a| return try GainNodeImpl.AudioNode_long_long(instance, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return try GainNodeImpl.AudioParam_long(instance, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try GainNodeImpl.call_addEventListener(instance, type_, callback, options);
    }

};

//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioBufferSourceNodeImpl = @import("../impls/AudioBufferSourceNode.zig");
const AudioScheduledSourceNode = @import("AudioScheduledSourceNode.zig");

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
        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,
        .call_disconnect = &call_disconnect,
        .call_disconnect = &call_disconnect,
        .call_disconnect = &call_disconnect,
        .call_disconnect = &call_disconnect,
        .call_disconnect = &call_disconnect,
        .call_disconnect = &call_disconnect,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
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
        
        // Initialize the state (Impl receives full hierarchy)
        AudioBufferSourceNodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try AudioBufferSourceNodeImpl.constructor(state, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_context(state);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_numberOfInputs(state);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_numberOfOutputs(state);
    }

    pub fn get_channelCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_channelCount(state);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_channelCount(state, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_channelCountMode(state);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_channelCountMode(state, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_channelInterpretation(state);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_channelInterpretation(state, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_onended(state, value);
    }

    pub fn get_buffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_buffer(state);
    }

    pub fn set_buffer(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_buffer(state, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_playbackRate(state);
    }

    pub fn get_detune(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_detune(state);
    }

    pub fn get_loop(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_loop(state);
    }

    pub fn set_loop(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_loop(state, value);
    }

    pub fn get_loopStart(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_loopStart(state);
    }

    pub fn set_loopStart(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_loopStart(state, value);
    }

    pub fn get_loopEnd(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AudioBufferSourceNodeImpl.get_loopEnd(state);
    }

    pub fn set_loopEnd(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        AudioBufferSourceNodeImpl.set_loopEnd(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferSourceNodeImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_stop(instance: *runtime.Instance, when: f64) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferSourceNodeImpl.call_stop(state, when);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferSourceNodeImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AudioBufferSourceNodeImpl.call_dispatchEvent(state, event);
    }

    /// Arguments for disconnect (WebIDL overloading)
    pub const DisconnectArgs = union(enum) {
        /// disconnect()
        no_params: void,
        /// disconnect(output)
        long: u32,
        /// disconnect(destinationNode)
        AudioNode: anyopaque,
        /// disconnect(destinationNode, output)
        AudioNode_long: struct {
            destinationNode: anyopaque,
            output: u32,
        },
        /// disconnect(destinationNode, output, input)
        AudioNode_long_long: struct {
            destinationNode: anyopaque,
            output: u32,
            input: u32,
        },
        /// disconnect(destinationParam)
        AudioParam: anyopaque,
        /// disconnect(destinationParam, output)
        AudioParam_long: struct {
            destinationParam: anyopaque,
            output: u32,
        },
    };

    pub fn call_disconnect(instance: *runtime.Instance, args: DisconnectArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return AudioBufferSourceNodeImpl.no_params(state),
            .long => |arg| return AudioBufferSourceNodeImpl.long(state, arg),
            .AudioNode => |arg| return AudioBufferSourceNodeImpl.AudioNode(state, arg),
            .AudioNode_long => |a| return AudioBufferSourceNodeImpl.AudioNode_long(state, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return AudioBufferSourceNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return AudioBufferSourceNodeImpl.AudioParam(state, arg),
            .AudioParam_long => |a| return AudioBufferSourceNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
        }
    }

    /// Arguments for start (WebIDL overloading)
    pub const StartArgs = union(enum) {
        /// start(when)
        double: f64,
        /// start(when, offset, duration)
        double_double_double: struct {
            when: f64,
            offset: f64,
            duration: f64,
        },
    };

    pub fn call_start(instance: *runtime.Instance, args: StartArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .double => |arg| return AudioBufferSourceNodeImpl.double(state, arg),
            .double_double_double => |a| return AudioBufferSourceNodeImpl.double_double_double(state, a.when, a.offset, a.duration),
        }
    }

    /// Arguments for connect (WebIDL overloading)
    pub const ConnectArgs = union(enum) {
        /// connect(destinationNode, output, input)
        AudioNode_long_long: struct {
            destinationNode: anyopaque,
            output: u32,
            input: u32,
        },
        /// connect(destinationParam, output)
        AudioParam_long: struct {
            destinationParam: anyopaque,
            output: u32,
        },
    };

    pub fn call_connect(instance: *runtime.Instance, args: ConnectArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .AudioNode_long_long => |a| return AudioBufferSourceNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return AudioBufferSourceNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioBufferSourceNodeImpl.call_addEventListener(state, type_, callback, options);
    }

};

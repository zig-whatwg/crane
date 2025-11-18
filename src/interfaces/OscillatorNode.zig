//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OscillatorNodeImpl = @import("../impls/OscillatorNode.zig");
const AudioScheduledSourceNode = @import("AudioScheduledSourceNode.zig");

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
            type: OscillatorType = undefined,
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
        .call_setPeriodicWave = &call_setPeriodicWave,
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
        OscillatorNodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        OscillatorNodeImpl.deinit(state);
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
        try OscillatorNodeImpl.constructor(state, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_context(state);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_numberOfInputs(state);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_numberOfOutputs(state);
    }

    pub fn get_channelCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_channelCount(state);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        OscillatorNodeImpl.set_channelCount(state, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_channelCountMode(state);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OscillatorNodeImpl.set_channelCountMode(state, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_channelInterpretation(state);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OscillatorNodeImpl.set_channelInterpretation(state, value);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OscillatorNodeImpl.set_onended(state, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_type(state);
    }

    pub fn set_type(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        OscillatorNodeImpl.set_type(state, value);
    }

    pub fn get_frequency(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_frequency(state);
    }

    pub fn get_detune(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return OscillatorNodeImpl.get_detune(state);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_stop(instance: *runtime.Instance, when: f64) anyopaque {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_stop(state, when);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_dispatchEvent(state, event);
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
            .no_params => return OscillatorNodeImpl.no_params(state),
            .long => |arg| return OscillatorNodeImpl.long(state, arg),
            .AudioNode => |arg| return OscillatorNodeImpl.AudioNode(state, arg),
            .AudioNode_long => |a| return OscillatorNodeImpl.AudioNode_long(state, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return OscillatorNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return OscillatorNodeImpl.AudioParam(state, arg),
            .AudioParam_long => |a| return OscillatorNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
        }
    }

    pub fn call_start(instance: *runtime.Instance, when: f64) anyopaque {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_start(state, when);
    }

    pub fn call_setPeriodicWave(instance: *runtime.Instance, periodicWave: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_setPeriodicWave(state, periodicWave);
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
            .AudioNode_long_long => |a| return OscillatorNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return OscillatorNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return OscillatorNodeImpl.call_addEventListener(state, type_, callback, options);
    }

};

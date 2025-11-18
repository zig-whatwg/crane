//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnalyserNodeImpl = @import("../impls/AnalyserNode.zig");
const AudioNode = @import("AudioNode.zig");

pub const AnalyserNode = struct {
    pub const Meta = struct {
        pub const name = "AnalyserNode";
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
            fftSize: u32 = undefined,
            frequencyBinCount: u32 = undefined,
            minDecibels: f64 = undefined,
            maxDecibels: f64 = undefined,
            smoothingTimeConstant: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AnalyserNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_context = &get_context,
        .get_fftSize = &get_fftSize,
        .get_frequencyBinCount = &get_frequencyBinCount,
        .get_maxDecibels = &get_maxDecibels,
        .get_minDecibels = &get_minDecibels,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,
        .get_smoothingTimeConstant = &get_smoothingTimeConstant,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,
        .set_fftSize = &set_fftSize,
        .set_maxDecibels = &set_maxDecibels,
        .set_minDecibels = &set_minDecibels,
        .set_smoothingTimeConstant = &set_smoothingTimeConstant,

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
        .call_getByteFrequencyData = &call_getByteFrequencyData,
        .call_getByteTimeDomainData = &call_getByteTimeDomainData,
        .call_getFloatFrequencyData = &call_getFloatFrequencyData,
        .call_getFloatTimeDomainData = &call_getFloatTimeDomainData,
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
        
        // Initialize the state (Impl receives full hierarchy)
        AnalyserNodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.deinit(state);
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
        try AnalyserNodeImpl.constructor(state, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_context(state);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_numberOfInputs(state);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_numberOfOutputs(state);
    }

    pub fn get_channelCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_channelCount(state);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_channelCount(state, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_channelCountMode(state);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_channelCountMode(state, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_channelInterpretation(state);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_channelInterpretation(state, value);
    }

    pub fn get_fftSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_fftSize(state);
    }

    pub fn set_fftSize(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_fftSize(state, value);
    }

    pub fn get_frequencyBinCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_frequencyBinCount(state);
    }

    pub fn get_minDecibels(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_minDecibels(state);
    }

    pub fn set_minDecibels(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_minDecibels(state, value);
    }

    pub fn get_maxDecibels(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_maxDecibels(state);
    }

    pub fn set_maxDecibels(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_maxDecibels(state, value);
    }

    pub fn get_smoothingTimeConstant(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return AnalyserNodeImpl.get_smoothingTimeConstant(state);
    }

    pub fn set_smoothingTimeConstant(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        AnalyserNodeImpl.set_smoothingTimeConstant(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_getByteTimeDomainData(instance: *runtime.Instance, array: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_getByteTimeDomainData(state, array);
    }

    pub fn call_getByteFrequencyData(instance: *runtime.Instance, array: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_getByteFrequencyData(state, array);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_when(state, type_, options);
    }

    pub fn call_getFloatFrequencyData(instance: *runtime.Instance, array: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_getFloatFrequencyData(state, array);
    }

    pub fn call_getFloatTimeDomainData(instance: *runtime.Instance, array: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_getFloatTimeDomainData(state, array);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_dispatchEvent(state, event);
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
            .no_params => return AnalyserNodeImpl.no_params(state),
            .long => |arg| return AnalyserNodeImpl.long(state, arg),
            .AudioNode => |arg| return AnalyserNodeImpl.AudioNode(state, arg),
            .AudioNode_long => |a| return AnalyserNodeImpl.AudioNode_long(state, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return AnalyserNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return AnalyserNodeImpl.AudioParam(state, arg),
            .AudioParam_long => |a| return AnalyserNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
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
            .AudioNode_long_long => |a| return AnalyserNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return AnalyserNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AnalyserNodeImpl.call_addEventListener(state, type_, callback, options);
    }

};

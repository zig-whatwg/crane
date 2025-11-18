//! Generated from: webaudio.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PannerNodeImpl = @import("../impls/PannerNode.zig");
const AudioNode = @import("AudioNode.zig");

pub const PannerNode = struct {
    pub const Meta = struct {
        pub const name = "PannerNode";
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
            panningModel: PanningModelType = undefined,
            positionX: AudioParam = undefined,
            positionY: AudioParam = undefined,
            positionZ: AudioParam = undefined,
            orientationX: AudioParam = undefined,
            orientationY: AudioParam = undefined,
            orientationZ: AudioParam = undefined,
            distanceModel: DistanceModelType = undefined,
            refDistance: f64 = undefined,
            maxDistance: f64 = undefined,
            rolloffFactor: f64 = undefined,
            coneInnerAngle: f64 = undefined,
            coneOuterAngle: f64 = undefined,
            coneOuterGain: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PannerNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_channelCount = &get_channelCount,
        .get_channelCountMode = &get_channelCountMode,
        .get_channelInterpretation = &get_channelInterpretation,
        .get_coneInnerAngle = &get_coneInnerAngle,
        .get_coneOuterAngle = &get_coneOuterAngle,
        .get_coneOuterGain = &get_coneOuterGain,
        .get_context = &get_context,
        .get_distanceModel = &get_distanceModel,
        .get_maxDistance = &get_maxDistance,
        .get_numberOfInputs = &get_numberOfInputs,
        .get_numberOfOutputs = &get_numberOfOutputs,
        .get_orientationX = &get_orientationX,
        .get_orientationY = &get_orientationY,
        .get_orientationZ = &get_orientationZ,
        .get_panningModel = &get_panningModel,
        .get_positionX = &get_positionX,
        .get_positionY = &get_positionY,
        .get_positionZ = &get_positionZ,
        .get_refDistance = &get_refDistance,
        .get_rolloffFactor = &get_rolloffFactor,

        .set_channelCount = &set_channelCount,
        .set_channelCountMode = &set_channelCountMode,
        .set_channelInterpretation = &set_channelInterpretation,
        .set_coneInnerAngle = &set_coneInnerAngle,
        .set_coneOuterAngle = &set_coneOuterAngle,
        .set_coneOuterGain = &set_coneOuterGain,
        .set_distanceModel = &set_distanceModel,
        .set_maxDistance = &set_maxDistance,
        .set_panningModel = &set_panningModel,
        .set_refDistance = &set_refDistance,
        .set_rolloffFactor = &set_rolloffFactor,

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
        .call_setOrientation = &call_setOrientation,
        .call_setPosition = &call_setPosition,
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
        PannerNodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PannerNodeImpl.deinit(state);
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
        try PannerNodeImpl.constructor(state, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_context(state);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_numberOfInputs(state);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_numberOfOutputs(state);
    }

    pub fn get_channelCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_channelCount(state);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_channelCount(state, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_channelCountMode(state);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_channelCountMode(state, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_channelInterpretation(state);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_channelInterpretation(state, value);
    }

    pub fn get_panningModel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_panningModel(state);
    }

    pub fn set_panningModel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_panningModel(state, value);
    }

    pub fn get_positionX(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_positionX(state);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_positionY(state);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_positionZ(state);
    }

    pub fn get_orientationX(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_orientationX(state);
    }

    pub fn get_orientationY(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_orientationY(state);
    }

    pub fn get_orientationZ(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_orientationZ(state);
    }

    pub fn get_distanceModel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PannerNodeImpl.get_distanceModel(state);
    }

    pub fn set_distanceModel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_distanceModel(state, value);
    }

    pub fn get_refDistance(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_refDistance(state);
    }

    pub fn set_refDistance(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_refDistance(state, value);
    }

    pub fn get_maxDistance(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_maxDistance(state);
    }

    pub fn set_maxDistance(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_maxDistance(state, value);
    }

    pub fn get_rolloffFactor(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_rolloffFactor(state);
    }

    pub fn set_rolloffFactor(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_rolloffFactor(state, value);
    }

    pub fn get_coneInnerAngle(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_coneInnerAngle(state);
    }

    pub fn set_coneInnerAngle(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_coneInnerAngle(state, value);
    }

    pub fn get_coneOuterAngle(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_coneOuterAngle(state);
    }

    pub fn set_coneOuterAngle(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_coneOuterAngle(state, value);
    }

    pub fn get_coneOuterGain(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PannerNodeImpl.get_coneOuterGain(state);
    }

    pub fn set_coneOuterGain(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PannerNodeImpl.set_coneOuterGain(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PannerNodeImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyopaque {
        const state = instance.getState(State);
        
        return PannerNodeImpl.call_setPosition(state, x, y, z);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PannerNodeImpl.call_when(state, type_, options);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyopaque {
        const state = instance.getState(State);
        
        return PannerNodeImpl.call_setOrientation(state, x, y, z);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PannerNodeImpl.call_dispatchEvent(state, event);
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
            .no_params => return PannerNodeImpl.no_params(state),
            .long => |arg| return PannerNodeImpl.long(state, arg),
            .AudioNode => |arg| return PannerNodeImpl.AudioNode(state, arg),
            .AudioNode_long => |a| return PannerNodeImpl.AudioNode_long(state, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return PannerNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return PannerNodeImpl.AudioParam(state, arg),
            .AudioParam_long => |a| return PannerNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
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
            .AudioNode_long_long => |a| return PannerNodeImpl.AudioNode_long_long(state, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return PannerNodeImpl.AudioParam_long(state, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PannerNodeImpl.call_addEventListener(state, type_, callback, options);
    }

};

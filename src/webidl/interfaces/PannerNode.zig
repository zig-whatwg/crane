//! Generated from: webaudio.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PannerNodeImpl = @import("impls").PannerNode;
const AudioNode = @import("interfaces").AudioNode;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const PanningModelType = @import("enums").PanningModelType;
const PannerOptions = @import("dictionaries").PannerOptions;
const AudioParam = @import("interfaces").AudioParam;
const DistanceModelType = @import("enums").DistanceModelType;

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
        
        // Initialize the instance (Impl receives full instance)
        PannerNodeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PannerNodeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: BaseAudioContext, options: PannerOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PannerNodeImpl.constructor(instance, context, options);
        
        return instance;
    }

    pub fn get_context(instance: *runtime.Instance) anyerror!BaseAudioContext {
        return try PannerNodeImpl.get_context(instance);
    }

    pub fn get_numberOfInputs(instance: *runtime.Instance) anyerror!u32 {
        return try PannerNodeImpl.get_numberOfInputs(instance);
    }

    pub fn get_numberOfOutputs(instance: *runtime.Instance) anyerror!u32 {
        return try PannerNodeImpl.get_numberOfOutputs(instance);
    }

    pub fn get_channelCount(instance: *runtime.Instance) anyerror!u32 {
        return try PannerNodeImpl.get_channelCount(instance);
    }

    pub fn set_channelCount(instance: *runtime.Instance, value: u32) anyerror!void {
        try PannerNodeImpl.set_channelCount(instance, value);
    }

    pub fn get_channelCountMode(instance: *runtime.Instance) anyerror!ChannelCountMode {
        return try PannerNodeImpl.get_channelCountMode(instance);
    }

    pub fn set_channelCountMode(instance: *runtime.Instance, value: ChannelCountMode) anyerror!void {
        try PannerNodeImpl.set_channelCountMode(instance, value);
    }

    pub fn get_channelInterpretation(instance: *runtime.Instance) anyerror!ChannelInterpretation {
        return try PannerNodeImpl.get_channelInterpretation(instance);
    }

    pub fn set_channelInterpretation(instance: *runtime.Instance, value: ChannelInterpretation) anyerror!void {
        try PannerNodeImpl.set_channelInterpretation(instance, value);
    }

    pub fn get_panningModel(instance: *runtime.Instance) anyerror!PanningModelType {
        return try PannerNodeImpl.get_panningModel(instance);
    }

    pub fn set_panningModel(instance: *runtime.Instance, value: PanningModelType) anyerror!void {
        try PannerNodeImpl.set_panningModel(instance, value);
    }

    pub fn get_positionX(instance: *runtime.Instance) anyerror!AudioParam {
        return try PannerNodeImpl.get_positionX(instance);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyerror!AudioParam {
        return try PannerNodeImpl.get_positionY(instance);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyerror!AudioParam {
        return try PannerNodeImpl.get_positionZ(instance);
    }

    pub fn get_orientationX(instance: *runtime.Instance) anyerror!AudioParam {
        return try PannerNodeImpl.get_orientationX(instance);
    }

    pub fn get_orientationY(instance: *runtime.Instance) anyerror!AudioParam {
        return try PannerNodeImpl.get_orientationY(instance);
    }

    pub fn get_orientationZ(instance: *runtime.Instance) anyerror!AudioParam {
        return try PannerNodeImpl.get_orientationZ(instance);
    }

    pub fn get_distanceModel(instance: *runtime.Instance) anyerror!DistanceModelType {
        return try PannerNodeImpl.get_distanceModel(instance);
    }

    pub fn set_distanceModel(instance: *runtime.Instance, value: DistanceModelType) anyerror!void {
        try PannerNodeImpl.set_distanceModel(instance, value);
    }

    pub fn get_refDistance(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_refDistance(instance);
    }

    pub fn set_refDistance(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_refDistance(instance, value);
    }

    pub fn get_maxDistance(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_maxDistance(instance);
    }

    pub fn set_maxDistance(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_maxDistance(instance, value);
    }

    pub fn get_rolloffFactor(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_rolloffFactor(instance);
    }

    pub fn set_rolloffFactor(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_rolloffFactor(instance, value);
    }

    pub fn get_coneInnerAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_coneInnerAngle(instance);
    }

    pub fn set_coneInnerAngle(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_coneInnerAngle(instance, value);
    }

    pub fn get_coneOuterAngle(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_coneOuterAngle(instance);
    }

    pub fn set_coneOuterAngle(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_coneOuterAngle(instance, value);
    }

    pub fn get_coneOuterGain(instance: *runtime.Instance) anyerror!f64 {
        return try PannerNodeImpl.get_coneOuterGain(instance);
    }

    pub fn set_coneOuterGain(instance: *runtime.Instance, value: f64) anyerror!void {
        try PannerNodeImpl.set_coneOuterGain(instance, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PannerNodeImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        
        return try PannerNodeImpl.call_setPosition(instance, x, y, z);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PannerNodeImpl.call_when(instance, type_, options);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        
        return try PannerNodeImpl.call_setOrientation(instance, x, y, z);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PannerNodeImpl.call_dispatchEvent(instance, event);
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
            .no_params => return try PannerNodeImpl.no_params(instance),
            .long => |arg| return try PannerNodeImpl.long(instance, arg),
            .AudioNode => |arg| return try PannerNodeImpl.AudioNode(instance, arg),
            .AudioNode_long => |a| return try PannerNodeImpl.AudioNode_long(instance, a.destinationNode, a.output),
            .AudioNode_long_long => |a| return try PannerNodeImpl.AudioNode_long_long(instance, a.destinationNode, a.output, a.input),
            .AudioParam => |arg| return try PannerNodeImpl.AudioParam(instance, arg),
            .AudioParam_long => |a| return try PannerNodeImpl.AudioParam_long(instance, a.destinationParam, a.output),
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
            .AudioNode_long_long => |a| return try PannerNodeImpl.AudioNode_long_long(instance, a.destinationNode, a.output, a.input),
            .AudioParam_long => |a| return try PannerNodeImpl.AudioParam_long(instance, a.destinationParam, a.output),
        }
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PannerNodeImpl.call_addEventListener(instance, type_, callback, options);
    }

};

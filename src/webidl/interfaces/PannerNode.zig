//! Generated from: webaudio.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PannerNodeImpl = @import("impls").PannerNode;
const AudioNode = @import("interfaces").AudioNode;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const BaseAudioContext = @import("interfaces").BaseAudioContext;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DistanceModelType = @import("enums").DistanceModelType;
const ChannelCountMode = @import("enums").ChannelCountMode;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioParam = @import("interfaces").AudioParam;
const PanningModelType = @import("enums").PanningModelType;
const PannerOptions = @import("dictionaries").PannerOptions;
const EventListener = @import("interfaces").EventListener;
const ChannelInterpretation = @import("enums").ChannelInterpretation;
const DOMString = @import("typedefs").DOMString;

pub const PannerNode = struct {
    pub const Meta = struct {
        pub const name = "PannerNode";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AudioNode;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "panningModel", "get_panningModel", "set_panningModel" },
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "orientationX", "get_orientationX", null },
            .{ "orientationY", "get_orientationY", null },
            .{ "orientationZ", "get_orientationZ", null },
            .{ "distanceModel", "get_distanceModel", "set_distanceModel" },
            .{ "refDistance", "get_refDistance", "set_refDistance" },
            .{ "maxDistance", "get_maxDistance", "set_maxDistance" },
            .{ "rolloffFactor", "get_rolloffFactor", "set_rolloffFactor" },
            .{ "coneInnerAngle", "get_coneInnerAngle", "set_coneInnerAngle" },
            .{ "coneOuterAngle", "get_coneOuterAngle", "set_coneOuterAngle" },
            .{ "coneOuterGain", "get_coneOuterGain", "set_coneOuterGain" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setPosition", "call_setPosition", 3 },
            .{ "setOrientation", "call_setOrientation", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPosition",
            "setOrientation",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "connect",
            "connect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
            "disconnect",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "panningModel", "get_panningModel", "set_panningModel" },
            .{ "positionX", "get_positionX", null },
            .{ "positionY", "get_positionY", null },
            .{ "positionZ", "get_positionZ", null },
            .{ "orientationX", "get_orientationX", null },
            .{ "orientationY", "get_orientationY", null },
            .{ "orientationZ", "get_orientationZ", null },
            .{ "distanceModel", "get_distanceModel", "set_distanceModel" },
            .{ "refDistance", "get_refDistance", "set_refDistance" },
            .{ "maxDistance", "get_maxDistance", "set_maxDistance" },
            .{ "rolloffFactor", "get_rolloffFactor", "set_rolloffFactor" },
            .{ "coneInnerAngle", "get_coneInnerAngle", "set_coneInnerAngle" },
            .{ "coneOuterAngle", "get_coneOuterAngle", "set_coneOuterAngle" },
            .{ "coneOuterGain", "get_coneOuterGain", "set_coneOuterGain" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            panningModel: PanningModelType = undefined,
            positionX: *runtime.Instance = undefined,
            positionY: *runtime.Instance = undefined,
            positionZ: *runtime.Instance = undefined,
            orientationX: *runtime.Instance = undefined,
            orientationY: *runtime.Instance = undefined,
            orientationZ: *runtime.Instance = undefined,
            distanceModel: DistanceModelType = undefined,
            refDistance: f64 = undefined,
            maxDistance: f64 = undefined,
            rolloffFactor: f64 = undefined,
            coneInnerAngle: f64 = undefined,
            coneOuterAngle: f64 = undefined,
            coneOuterGain: f64 = undefined,
            _internal: ?*PannerNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_coneInnerAngle = &get_coneInnerAngle,
        .get_coneOuterAngle = &get_coneOuterAngle,
        .get_coneOuterGain = &get_coneOuterGain,
        .get_distanceModel = &get_distanceModel,
        .get_maxDistance = &get_maxDistance,
        .get_orientationX = &get_orientationX,
        .get_orientationY = &get_orientationY,
        .get_orientationZ = &get_orientationZ,
        .get_panningModel = &get_panningModel,
        .get_positionX = &get_positionX,
        .get_positionY = &get_positionY,
        .get_positionZ = &get_positionZ,
        .get_refDistance = &get_refDistance,
        .get_rolloffFactor = &get_rolloffFactor,

        .set_coneInnerAngle = &set_coneInnerAngle,
        .set_coneOuterAngle = &set_coneOuterAngle,
        .set_coneOuterGain = &set_coneOuterGain,
        .set_distanceModel = &set_distanceModel,
        .set_maxDistance = &set_maxDistance,
        .set_panningModel = &set_panningModel,
        .set_refDistance = &set_refDistance,
        .set_rolloffFactor = &set_rolloffFactor,

        .call_setOrientation = &call_setOrientation,
        .call_setPosition = &call_setPosition,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PannerNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PannerNodeImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance, options: PannerOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PannerNodeImpl.call_constructor(allocator, ctx, context, options);
    }

    pub fn get_panningModel(instance: *runtime.Instance) anyerror!PanningModelType {
        return try PannerNodeImpl.get_panningModel(instance);
    }

    pub fn set_panningModel(instance: *runtime.Instance, value: PanningModelType) anyerror!void {
        try PannerNodeImpl.set_panningModel(instance, value);
    }

    pub fn get_positionX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_positionX(instance);
    }

    pub fn get_positionY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_positionY(instance);
    }

    pub fn get_positionZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_positionZ(instance);
    }

    pub fn get_orientationX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_orientationX(instance);
    }

    pub fn get_orientationY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PannerNodeImpl.get_orientationY(instance);
    }

    pub fn get_orientationZ(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

    pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        
        return try PannerNodeImpl.call_setPosition(instance, x, y, z);
    }

    pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32) anyerror!void {
        
        return try PannerNodeImpl.call_setOrientation(instance, x, y, z);
    }

};

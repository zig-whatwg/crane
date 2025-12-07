//! Generated from: orientation-sensor.idl
//! Generated at: 2025-12-07T19:33:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const OrientationSensorImpl = @import("impls").OrientationSensor;
const mixins = @import("mixins");
const Sensor = @import("interfaces").Sensor;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const RotationMatrixType = @import("typedefs").RotationMatrixType;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const OrientationSensor = struct {
    pub const Meta = struct {
        pub const name = "OrientationSensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Sensor.State;
        pub const ParentInterface = Sensor;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "quaternion", "get_quaternion", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "populateMatrix", "call_populateMatrix", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "populateMatrix",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "start",
            "stop",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "quaternion", "get_quaternion", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            quaternion: ?runtime.FrozenArray(f64) = null,
            _internal: ?*OrientationSensorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_quaternion = &get_quaternion,

        .call_populateMatrix = &call_populateMatrix,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OrientationSensorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OrientationSensorImpl.deinit(instance);
    }

    pub fn get_quaternion(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try OrientationSensorImpl.get_quaternion(instance);
    }

    pub fn call_populateMatrix(instance: *runtime.Instance, targetMatrix: RotationMatrixType) anyerror!void {
        
        return try OrientationSensorImpl.call_populateMatrix(instance, targetMatrix);
    }

};

//! Generated from: magnetometer.idl
//! Generated at: 2025-11-28T18:02:26Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const UncalibratedMagnetometerImpl = @import("impls").UncalibratedMagnetometer;
const Sensor = @import("interfaces").Sensor;
const MagnetometerSensorOptions = @import("dictionaries").MagnetometerSensorOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const UncalibratedMagnetometer = struct {
    pub const Meta = struct {
        pub const name = "UncalibratedMagnetometer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Sensor;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
            .{ "xBias", "get_xBias", null },
            .{ "yBias", "get_yBias", null },
            .{ "zBias", "get_zBias", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
            .{ "xBias", "get_xBias", null },
            .{ "yBias", "get_yBias", null },
            .{ "zBias", "get_zBias", null },
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
            x: ?f64 = null,
            y: ?f64 = null,
            z: ?f64 = null,
            xBias: ?f64 = null,
            yBias: ?f64 = null,
            zBias: ?f64 = null,
            _internal: ?*UncalibratedMagnetometerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_x = &get_x,
        .get_xBias = &get_xBias,
        .get_y = &get_y,
        .get_yBias = &get_yBias,
        .get_z = &get_z,
        .get_zBias = &get_zBias,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return UncalibratedMagnetometerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        UncalibratedMagnetometerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, sensorOptions: MagnetometerSensorOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try UncalibratedMagnetometerImpl.call_constructor(allocator, ctx, sensorOptions);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!?f64 {
        return try UncalibratedMagnetometerImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!?f64 {
        return try UncalibratedMagnetometerImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!?f64 {
        return try UncalibratedMagnetometerImpl.get_z(instance);
    }

    pub fn get_xBias(instance: *runtime.Instance) anyerror!?f64 {
        return try UncalibratedMagnetometerImpl.get_xBias(instance);
    }

    pub fn get_yBias(instance: *runtime.Instance) anyerror!?f64 {
        return try UncalibratedMagnetometerImpl.get_yBias(instance);
    }

    pub fn get_zBias(instance: *runtime.Instance) anyerror!?f64 {
        return try UncalibratedMagnetometerImpl.get_zBias(instance);
    }

};

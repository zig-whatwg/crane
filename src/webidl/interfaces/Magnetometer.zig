//! Generated from: magnetometer.idl
//! Generated at: 2025-11-29T02:15:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MagnetometerImpl = @import("impls").Magnetometer;
const mixins = @import("mixins");
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

pub const Magnetometer = struct {
    pub const Meta = struct {
        pub const name = "Magnetometer";
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
            _internal: ?*MagnetometerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MagnetometerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MagnetometerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, sensorOptions: webidl.Opt(MagnetometerSensorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MagnetometerImpl.call_constructor(allocator, ctx, sensorOptions);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!?f64 {
        return try MagnetometerImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!?f64 {
        return try MagnetometerImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!?f64 {
        return try MagnetometerImpl.get_z(instance);
    }

};

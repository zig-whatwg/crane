//! Generated from: geolocation-sensor.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GeolocationSensorImpl = @import("impls").GeolocationSensor;
const mixins = @import("mixins");
const Sensor = @import("interfaces").Sensor;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ReadOptions = @import("dictionaries").ReadOptions;
const GeolocationSensorReading = @import("dictionaries").GeolocationSensorReading;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const GeolocationSensorOptions = @import("dictionaries").GeolocationSensorOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const GeolocationSensor = struct {
    pub const Meta = struct {
        pub const name = "GeolocationSensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Sensor.State;
        pub const ParentInterface = Sensor;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "latitude", "get_latitude", null },
            .{ "longitude", "get_longitude", null },
            .{ "altitude", "get_altitude", null },
            .{ "accuracy", "get_accuracy", null },
            .{ "altitudeAccuracy", "get_altitudeAccuracy", null },
            .{ "heading", "get_heading", null },
            .{ "speed", "get_speed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "read", "call_static_read", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "read",
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
            .{ "latitude", "get_latitude", null },
            .{ "longitude", "get_longitude", null },
            .{ "altitude", "get_altitude", null },
            .{ "accuracy", "get_accuracy", null },
            .{ "altitudeAccuracy", "get_altitudeAccuracy", null },
            .{ "heading", "get_heading", null },
            .{ "speed", "get_speed", null },
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
            latitude: ?f64 = null,
            longitude: ?f64 = null,
            altitude: ?f64 = null,
            accuracy: ?f64 = null,
            altitudeAccuracy: ?f64 = null,
            heading: ?f64 = null,
            speed: ?f64 = null,
            _internal: ?*GeolocationSensorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_accuracy = &get_accuracy,
        .get_altitude = &get_altitude,
        .get_altitudeAccuracy = &get_altitudeAccuracy,
        .get_heading = &get_heading,
        .get_latitude = &get_latitude,
        .get_longitude = &get_longitude,
        .get_speed = &get_speed,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GeolocationSensorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return GeolocationSensorImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GeolocationSensorImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(GeolocationSensorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try GeolocationSensorImpl.call_constructor(ctx, options);
    }

    pub fn get_latitude(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_latitude(instance);
    }

    pub fn get_longitude(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_longitude(instance);
    }

    pub fn get_altitude(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_altitude(instance);
    }

    pub fn get_accuracy(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_accuracy(instance);
    }

    pub fn get_altitudeAccuracy(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_altitudeAccuracy(instance);
    }

    pub fn get_heading(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_heading(instance);
    }

    pub fn get_speed(instance: *runtime.Instance) anyerror!?f64 {
        return try GeolocationSensorImpl.get_speed(instance);
    }

    pub fn call_static_read(instance: *runtime.Instance, readOptions: webidl.Opt(ReadOptions)) anyerror!*const anyopaque {
        
        return try GeolocationSensorImpl.call_static_read(instance, readOptions);
    }

};

//! Generated from: proximity.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ProximitySensorImpl = @import("impls").ProximitySensor;
const mixins = @import("mixins");
const Sensor = @import("interfaces").Sensor;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const SensorOptions = @import("dictionaries").SensorOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const ProximitySensor = struct {
    pub const Meta = struct {
        pub const name = "ProximitySensor";
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
            .{ "distance", "get_distance", null },
            .{ "max", "get_max", null },
            .{ "near", "get_near", null },
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
            .{ "distance", "get_distance", null },
            .{ "max", "get_max", null },
            .{ "near", "get_near", null },
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
            distance: ?f64 = null,
            max: ?f64 = null,
            near: ?bool = null,
            _internal: ?*ProximitySensorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_distance = &get_distance,
        .get_max = &get_max,
        .get_near = &get_near,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ProximitySensorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProximitySensorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, sensorOptions: webidl.Opt(SensorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ProximitySensorImpl.call_constructor(allocator, ctx, sensorOptions);
    }

    pub fn get_distance(instance: *runtime.Instance) anyerror!?f64 {
        return try ProximitySensorImpl.get_distance(instance);
    }

    pub fn get_max(instance: *runtime.Instance) anyerror!?f64 {
        return try ProximitySensorImpl.get_max(instance);
    }

    pub fn get_near(instance: *runtime.Instance) anyerror!?bool {
        return try ProximitySensorImpl.get_near(instance);
    }

};

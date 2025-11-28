//! Generated from: generic-sensor.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SensorImpl = @import("impls").Sensor;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const Sensor = struct {
    pub const Meta = struct {
        pub const name = "Sensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            .{ "activated", "get_activated", null },
            .{ "hasReading", "get_hasReading", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onactivate", "get_onactivate", "set_onactivate" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "activated", "get_activated", null },
            .{ "hasReading", "get_hasReading", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "onreading", "get_onreading", "set_onreading" },
            .{ "onactivate", "get_onactivate", "set_onactivate" },
            .{ "onerror", "get_onerror", "set_onerror" },
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
            activated: bool = undefined,
            hasReading: bool = undefined,
            timestamp: ?DOMHighResTimeStamp = null,
            onreading: EventHandler = undefined,
            onactivate: EventHandler = undefined,
            onerror: EventHandler = undefined,
            _internal: ?*SensorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activated = &get_activated,
        .get_hasReading = &get_hasReading,
        .get_onactivate = &get_onactivate,
        .get_onerror = &get_onerror,
        .get_onreading = &get_onreading,
        .get_timestamp = &get_timestamp,

        .set_onactivate = &set_onactivate,
        .set_onerror = &set_onerror,
        .set_onreading = &set_onreading,

        .call_start = &call_start,
        .call_stop = &call_stop,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SensorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SensorImpl.deinit(instance);
    }

    pub fn get_activated(instance: *runtime.Instance) anyerror!bool {
        return try SensorImpl.get_activated(instance);
    }

    pub fn get_hasReading(instance: *runtime.Instance) anyerror!bool {
        return try SensorImpl.get_hasReading(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try SensorImpl.get_timestamp(instance);
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try SensorImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SensorImpl.set_onreading(instance, value);
    }

    pub fn get_onactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SensorImpl.get_onactivate(instance);
    }

    pub fn set_onactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SensorImpl.set_onactivate(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SensorImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SensorImpl.set_onerror(instance, value);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try SensorImpl.call_stop(instance);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try SensorImpl.call_start(instance);
    }

};

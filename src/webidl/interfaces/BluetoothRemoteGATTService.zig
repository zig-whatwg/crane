//! Generated from: web-bluetooth.idl
//! Generated at: 2025-12-05T20:30:47Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothRemoteGATTServiceImpl = @import("impls").BluetoothRemoteGATTService;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("interfaces").ServiceEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const UUID = @import("typedefs").UUID;
const BluetoothServiceUUID = @import("typedefs").BluetoothServiceUUID;
const BluetoothCharacteristicUUID = @import("typedefs").BluetoothCharacteristicUUID;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BluetoothRemoteGATTCharacteristic = @import("interfaces").BluetoothRemoteGATTCharacteristic;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const BluetoothRemoteGATTService = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTService";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            CharacteristicEventHandlers,
            ServiceEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "device", "get_device", null },
            .{ "uuid", "get_uuid", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCharacteristic", "call_getCharacteristic", 1 },
            .{ "getCharacteristics", "call_getCharacteristics", 0 },
            .{ "getIncludedService", "call_getIncludedService", 1 },
            .{ "getIncludedServices", "call_getIncludedServices", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCharacteristic",
            "getCharacteristics",
            "getIncludedService",
            "getIncludedServices",
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
            .{ "device", "get_device", null },
            .{ "uuid", "get_uuid", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            device: *runtime.Instance = undefined,
            uuid: UUID = undefined,
            isPrimary: bool = undefined,
            oncharacteristicvaluechanged: EventHandler = undefined,
            onserviceadded: EventHandler = undefined,
            onservicechanged: EventHandler = undefined,
            onserviceremoved: EventHandler = undefined,
            cached_device: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTServiceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_device = &get_device,
        .get_isPrimary = &get_isPrimary,
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,
        .get_uuid = &get_uuid,

        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,

        .call_getCharacteristic = &call_getCharacteristic,
        .call_getCharacteristics = &call_getCharacteristics,
        .call_getIncludedService = &call_getIncludedService,
        .call_getIncludedServices = &call_getIncludedServices,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothRemoteGATTServiceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTServiceImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTServiceImpl.get_device(instance);
        state.own.cached_device = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTServiceImpl.get_uuid(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothRemoteGATTServiceImpl.get_isPrimary(instance);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothRemoteGATTServiceImpl.get_oncharacteristicvaluechanged(instance);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothRemoteGATTServiceImpl.set_oncharacteristicvaluechanged(instance, value);
    }

    pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothRemoteGATTServiceImpl.get_onserviceadded(instance);
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothRemoteGATTServiceImpl.set_onserviceadded(instance, value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothRemoteGATTServiceImpl.get_onservicechanged(instance);
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothRemoteGATTServiceImpl.set_onservicechanged(instance, value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothRemoteGATTServiceImpl.get_onserviceremoved(instance);
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothRemoteGATTServiceImpl.set_onserviceremoved(instance, value);
    }

    pub fn call_getCharacteristic(instance: *runtime.Instance, characteristic: BluetoothCharacteristicUUID) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTServiceImpl.call_getCharacteristic(instance, characteristic);
    }

    pub fn call_getIncludedServices(instance: *runtime.Instance, service: webidl.Opt(BluetoothServiceUUID)) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTServiceImpl.call_getIncludedServices(instance, service);
    }

    pub fn call_getCharacteristics(instance: *runtime.Instance, characteristic: webidl.Opt(BluetoothCharacteristicUUID)) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTServiceImpl.call_getCharacteristics(instance, characteristic);
    }

    pub fn call_getIncludedService(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTServiceImpl.call_getIncludedService(instance, service);
    }
};

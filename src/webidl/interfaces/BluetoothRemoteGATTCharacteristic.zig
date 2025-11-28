//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothRemoteGATTCharacteristicImpl = @import("impls").BluetoothRemoteGATTCharacteristic;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const UUID = @import("typedefs").UUID;
const BluetoothCharacteristicProperties = @import("interfaces").BluetoothCharacteristicProperties;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BluetoothRemoteGATTDescriptor = @import("interfaces").BluetoothRemoteGATTDescriptor;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const BluetoothDescriptorUUID = @import("typedefs").BluetoothDescriptorUUID;
const BluetoothRemoteGATTService = @import("interfaces").BluetoothRemoteGATTService;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const BluetoothRemoteGATTCharacteristic = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTCharacteristic";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{
            CharacteristicEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "service", "get_service", null },
            .{ "uuid", "get_uuid", null },
            .{ "properties", "get_properties", null },
            .{ "value", "get_value", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getDescriptor", "call_getDescriptor", 1 },
            .{ "getDescriptors", "call_getDescriptors", 0 },
            .{ "readValue", "call_readValue", 0 },
            .{ "writeValue", "call_writeValue", 1 },
            .{ "writeValueWithResponse", "call_writeValueWithResponse", 1 },
            .{ "writeValueWithoutResponse", "call_writeValueWithoutResponse", 1 },
            .{ "startNotifications", "call_startNotifications", 0 },
            .{ "stopNotifications", "call_stopNotifications", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getDescriptor",
            "getDescriptors",
            "readValue",
            "writeValue",
            "writeValueWithResponse",
            "writeValueWithoutResponse",
            "startNotifications",
            "stopNotifications",
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
            .{ "service", "get_service", null },
            .{ "uuid", "get_uuid", null },
            .{ "properties", "get_properties", null },
            .{ "value", "get_value", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
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
            service: *runtime.Instance = undefined,
            uuid: UUID = undefined,
            properties: *runtime.Instance = undefined,
            value: ?runtime.DataView = null,
            oncharacteristicvaluechanged: EventHandler = undefined,
            cached_service: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTCharacteristicImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_properties = &get_properties,
        .get_service = &get_service,
        .get_uuid = &get_uuid,
        .get_value = &get_value,

        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,

        .call_getDescriptor = &call_getDescriptor,
        .call_getDescriptors = &call_getDescriptors,
        .call_readValue = &call_readValue,
        .call_startNotifications = &call_startNotifications,
        .call_stopNotifications = &call_stopNotifications,
        .call_writeValue = &call_writeValue,
        .call_writeValueWithResponse = &call_writeValueWithResponse,
        .call_writeValueWithoutResponse = &call_writeValueWithoutResponse,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothRemoteGATTCharacteristicImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTCharacteristicImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_service(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_service) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTCharacteristicImpl.get_service(instance);
        state.own.cached_service = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTCharacteristicImpl.get_uuid(instance);
    }

    pub fn get_properties(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BluetoothRemoteGATTCharacteristicImpl.get_properties(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.get_value(instance);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothRemoteGATTCharacteristicImpl.get_oncharacteristicvaluechanged(instance);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothRemoteGATTCharacteristicImpl.set_oncharacteristicvaluechanged(instance, value);
    }

    pub fn call_startNotifications(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.call_startNotifications(instance);
    }

    pub fn call_writeValueWithResponse(instance: *runtime.Instance, value: BufferSource) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithResponse(instance, value);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: BufferSource) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValue(instance, value);
    }

    pub fn call_getDescriptors(instance: *runtime.Instance, descriptor: webidl.Opt(BluetoothDescriptorUUID)) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_getDescriptors(instance, descriptor);
    }

    pub fn call_getDescriptor(instance: *runtime.Instance, descriptor: BluetoothDescriptorUUID) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_getDescriptor(instance, descriptor);
    }

    pub fn call_writeValueWithoutResponse(instance: *runtime.Instance, value: BufferSource) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithoutResponse(instance, value);
    }

    pub fn call_stopNotifications(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.call_stopNotifications(instance);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.call_readValue(instance);
    }

};

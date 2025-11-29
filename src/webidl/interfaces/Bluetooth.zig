//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-29T05:01:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothImpl = @import("impls").Bluetooth;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const BluetoothDeviceEventHandlers = @import("interfaces").BluetoothDeviceEventHandlers;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("interfaces").ServiceEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const BluetoothLEScan = @import("interfaces").BluetoothLEScan;
const RequestDeviceOptions = @import("dictionaries").RequestDeviceOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const BluetoothLEScanOptions = @import("dictionaries").BluetoothLEScanOptions;

pub const Bluetooth = struct {
    pub const Meta = struct {
        pub const name = "Bluetooth";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            BluetoothDeviceEventHandlers,
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
            .{ "onavailabilitychanged", "get_onavailabilitychanged", "set_onavailabilitychanged" },
            .{ "referringDevice", "get_referringDevice", null },
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getAvailability", "call_getAvailability", 0 },
            .{ "getDevices", "call_getDevices", 0 },
            .{ "requestDevice", "call_requestDevice", 0 },
            .{ "requestLEScan", "call_requestLEScan", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAvailability",
            "getDevices",
            "requestDevice",
            "requestLEScan",
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
            .{ "onavailabilitychanged", "get_onavailabilitychanged", "set_onavailabilitychanged" },
            .{ "referringDevice", "get_referringDevice", null },
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
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
            onavailabilitychanged: EventHandler = undefined,
            referringDevice: ?*runtime.Instance = null,
            onadvertisementreceived: EventHandler = undefined,
            ongattserverdisconnected: EventHandler = undefined,
            oncharacteristicvaluechanged: EventHandler = undefined,
            onserviceadded: EventHandler = undefined,
            onservicechanged: EventHandler = undefined,
            onserviceremoved: EventHandler = undefined,
            cached_referringDevice: ?*runtime.Instance = null,
            _internal: ?*BluetoothImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onadvertisementreceived = &get_onadvertisementreceived,
        .get_onavailabilitychanged = &get_onavailabilitychanged,
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_ongattserverdisconnected = &get_ongattserverdisconnected,
        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,
        .get_referringDevice = &get_referringDevice,

        .set_onadvertisementreceived = &set_onadvertisementreceived,
        .set_onavailabilitychanged = &set_onavailabilitychanged,
        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
        .set_ongattserverdisconnected = &set_ongattserverdisconnected,
        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,

        .call_getAvailability = &call_getAvailability,
        .call_getDevices = &call_getDevices,
        .call_requestDevice = &call_requestDevice,
        .call_requestLEScan = &call_requestLEScan,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothImpl.deinit(instance);
    }

    pub fn get_onavailabilitychanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_onavailabilitychanged(instance);
    }

    pub fn set_onavailabilitychanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_onavailabilitychanged(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_referringDevice(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_referringDevice) |cached| {
            return cached;
        }
        const value = try BluetoothImpl.get_referringDevice(instance);
        state.own.cached_referringDevice = value;
        return value;
    }

    pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_onadvertisementreceived(instance);
    }

    pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_onadvertisementreceived(instance, value);
    }

    pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_ongattserverdisconnected(instance);
    }

    pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_ongattserverdisconnected(instance, value);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_oncharacteristicvaluechanged(instance);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_oncharacteristicvaluechanged(instance, value);
    }

    pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_onserviceadded(instance);
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_onserviceadded(instance, value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_onservicechanged(instance);
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_onservicechanged(instance, value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_onserviceremoved(instance);
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_onserviceremoved(instance, value);
    }

    pub fn call_getDevices(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothImpl.call_getDevices(instance);
    }

    pub fn call_requestDevice(instance: *runtime.Instance, options: webidl.Opt(RequestDeviceOptions)) anyerror!*const anyopaque {
        
        return try BluetoothImpl.call_requestDevice(instance, options);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestLEScan(instance: *runtime.Instance, options: webidl.Opt(BluetoothLEScanOptions)) anyerror!*const anyopaque {
        
        return try BluetoothImpl.call_requestLEScan(instance, options);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothImpl.call_getAvailability(instance);
    }

};

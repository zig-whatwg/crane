//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothDeviceImpl = @import("impls").BluetoothDevice;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const BluetoothDeviceEventHandlers = @import("mixins").BluetoothDeviceEventHandlers;
const CharacteristicEventHandlers = @import("mixins").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("mixins").ServiceEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const BluetoothRemoteGATTServer = @import("BluetoothRemoteGATTServer.zig").BluetoothRemoteGATTServer;
const WatchAdvertisementsOptions = @import("dictionaries").WatchAdvertisementsOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const BluetoothDevice = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDevice";
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
            .{ "id", "get_id", null },
            .{ "name", "get_name", null },
            .{ "gatt", "get_gatt", null },
            .{ "watchingAdvertisements", "get_watchingAdvertisements", null },
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "forget", "call_forget", 0 },
            .{ "watchAdvertisements", "call_watchAdvertisements", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "forget",
            "watchAdvertisements",
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
            .{ "id", "get_id", null },
            .{ "name", "get_name", null },
            .{ "gatt", "get_gatt", null },
            .{ "watchingAdvertisements", "get_watchingAdvertisements", null },
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: typedefs.DOMString = undefined,
            name: ?typedefs.DOMString = null,
            gatt: ?*runtime.Instance = null,
            watchingAdvertisements: bool = undefined,
            onadvertisementreceived: typedefs.EventHandler = undefined,
            ongattserverdisconnected: typedefs.EventHandler = undefined,
            oncharacteristicvaluechanged: typedefs.EventHandler = undefined,
            onserviceadded: typedefs.EventHandler = undefined,
            onservicechanged: typedefs.EventHandler = undefined,
            onserviceremoved: typedefs.EventHandler = undefined,
            _internal: ?*BluetoothDeviceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_gatt = &get_gatt,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_onadvertisementreceived = &get_onadvertisementreceived,
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_ongattserverdisconnected = &get_ongattserverdisconnected,
        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,
        .get_watchingAdvertisements = &get_watchingAdvertisements,

        .set_onadvertisementreceived = &set_onadvertisementreceived,
        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
        .set_ongattserverdisconnected = &set_ongattserverdisconnected,
        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,

        .call_forget = &call_forget,
        .call_watchAdvertisements = &call_watchAdvertisements,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothDeviceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BluetoothDeviceImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothDeviceImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothDeviceImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?DOMString {
        return try BluetoothDeviceImpl.get_name(instance);
    }

    pub fn get_gatt(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try BluetoothDeviceImpl.get_gatt(instance);
    }

    pub fn get_watchingAdvertisements(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothDeviceImpl.get_watchingAdvertisements(instance);
    }

    pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceImpl.get_onadvertisementreceived(instance);
    }

    pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceImpl.set_onadvertisementreceived(instance, value);
    }

    pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceImpl.get_ongattserverdisconnected(instance);
    }

    pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceImpl.set_ongattserverdisconnected(instance, value);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceImpl.get_oncharacteristicvaluechanged(instance);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceImpl.set_oncharacteristicvaluechanged(instance, value);
    }

    pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceImpl.get_onserviceadded(instance);
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceImpl.set_onserviceadded(instance, value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceImpl.get_onservicechanged(instance);
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceImpl.set_onservicechanged(instance, value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceImpl.get_onserviceremoved(instance);
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceImpl.set_onserviceremoved(instance, value);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothDeviceImpl.call_forget(instance);
    }

    pub fn call_watchAdvertisements(instance: *runtime.Instance, options: webidl.Opt(WatchAdvertisementsOptions)) anyerror!runtime.JSValue {
        
        return try BluetoothDeviceImpl.call_watchAdvertisements(instance, options);
    }

};

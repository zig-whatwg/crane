//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothDeviceImpl = @import("impls").BluetoothDevice;
const EventTarget = @import("interfaces").EventTarget;
const BluetoothDeviceEventHandlers = @import("interfaces").BluetoothDeviceEventHandlers;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("interfaces").ServiceEventHandlers;
const BluetoothRemoteGATTServer = @import("interfaces").BluetoothRemoteGATTServer;
const WatchAdvertisementsOptions = @import("dictionaries").WatchAdvertisementsOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const BluetoothDevice = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDevice";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            id: runtime.DOMString = undefined,
            name: ?runtime.DOMString = null,
            gatt: ?BluetoothRemoteGATTServer = null,
            watchingAdvertisements: bool = undefined,
            onadvertisementreceived: EventHandler = undefined,
            ongattserverdisconnected: EventHandler = undefined,
            oncharacteristicvaluechanged: EventHandler = undefined,
            onserviceadded: EventHandler = undefined,
            onservicechanged: EventHandler = undefined,
            onserviceremoved: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothDevice, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_forget = &call_forget,
        .call_removeEventListener = &call_removeEventListener,
        .call_watchAdvertisements = &call_watchAdvertisements,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        BluetoothDeviceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothDeviceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothDeviceImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothDeviceImpl.get_name(instance);
    }

    pub fn get_gatt(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BluetoothDeviceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_watchAdvertisements(instance: *runtime.Instance, options: WatchAdvertisementsOptions) anyerror!anyopaque {
        
        return try BluetoothDeviceImpl.call_watchAdvertisements(instance, options);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothDeviceImpl.call_forget(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BluetoothDeviceImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothDeviceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothDeviceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

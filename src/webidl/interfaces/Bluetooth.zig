//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothImpl = @import("impls").Bluetooth;
const EventTarget = @import("interfaces").EventTarget;
const BluetoothDeviceEventHandlers = @import("interfaces").BluetoothDeviceEventHandlers;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("interfaces").ServiceEventHandlers;
const Promise<BluetoothLEScan> = @import("interfaces").Promise<BluetoothLEScan>;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const Promise<sequence<BluetoothDevice>> = @import("interfaces").Promise<sequence<BluetoothDevice>>;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<BluetoothDevice> = @import("interfaces").Promise<BluetoothDevice>;
const RequestDeviceOptions = @import("dictionaries").RequestDeviceOptions;
const EventHandler = @import("typedefs").EventHandler;
const BluetoothLEScanOptions = @import("dictionaries").BluetoothLEScanOptions;

pub const Bluetooth = struct {
    pub const Meta = struct {
        pub const name = "Bluetooth";
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
            onavailabilitychanged: EventHandler = undefined,
            referringDevice: ?BluetoothDevice = null,
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

    pub const vtable = runtime.buildVTable(Bluetooth, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAvailability = &call_getAvailability,
        .call_getDevices = &call_getDevices,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestDevice = &call_requestDevice,
        .call_requestLEScan = &call_requestLEScan,
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
        BluetoothImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onavailabilitychanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothImpl.get_onavailabilitychanged(instance);
    }

    pub fn set_onavailabilitychanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothImpl.set_onavailabilitychanged(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_referringDevice(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_referringDevice) |cached| {
            return cached;
        }
        const value = try BluetoothImpl.get_referringDevice(instance);
        state.cached_referringDevice = value;
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

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BluetoothImpl.call_when(instance, type_, options);
    }

    pub fn call_requestDevice(instance: *runtime.Instance, options: RequestDeviceOptions) anyerror!anyopaque {
        
        return try BluetoothImpl.call_requestDevice(instance, options);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_requestLEScan(instance: *runtime.Instance, options: BluetoothLEScanOptions) anyerror!anyopaque {
        
        return try BluetoothImpl.call_requestLEScan(instance, options);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothImpl.call_getAvailability(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BluetoothImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getDevices(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothImpl.call_getDevices(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothDeviceImpl = @import("../impls/BluetoothDevice.zig");
const EventTarget = @import("EventTarget.zig");
const BluetoothDeviceEventHandlers = @import("BluetoothDeviceEventHandlers.zig");
const CharacteristicEventHandlers = @import("CharacteristicEventHandlers.zig");
const ServiceEventHandlers = @import("ServiceEventHandlers.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothDeviceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_name(state);
    }

    pub fn get_gatt(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_gatt(state);
    }

    pub fn get_watchingAdvertisements(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_watchingAdvertisements(state);
    }

    pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_onadvertisementreceived(state);
    }

    pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.set_onadvertisementreceived(state, value);
    }

    pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_ongattserverdisconnected(state);
    }

    pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.set_ongattserverdisconnected(state, value);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_oncharacteristicvaluechanged(state);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.set_oncharacteristicvaluechanged(state, value);
    }

    pub fn get_onserviceadded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_onserviceadded(state);
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.set_onserviceadded(state, value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_onservicechanged(state);
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.set_onservicechanged(state, value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.get_onserviceremoved(state);
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceImpl.set_onserviceremoved(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BluetoothDeviceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_watchAdvertisements(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothDeviceImpl.call_watchAdvertisements(state, options);
    }

    pub fn call_forget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceImpl.call_forget(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothDeviceImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothDeviceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothDeviceImpl.call_removeEventListener(state, type_, callback, options);
    }

};

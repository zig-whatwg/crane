//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTServiceImpl = @import("../impls/BluetoothRemoteGATTService.zig");
const EventTarget = @import("EventTarget.zig");
const CharacteristicEventHandlers = @import("CharacteristicEventHandlers.zig");
const ServiceEventHandlers = @import("ServiceEventHandlers.zig");

pub const BluetoothRemoteGATTService = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTService";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
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
            device: BluetoothDevice = undefined,
            uuid: UUID = undefined,
            isPrimary: bool = undefined,
            oncharacteristicvaluechanged: EventHandler = undefined,
            onserviceadded: EventHandler = undefined,
            onservicechanged: EventHandler = undefined,
            onserviceremoved: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothRemoteGATTService, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getCharacteristic = &call_getCharacteristic,
        .call_getCharacteristics = &call_getCharacteristics,
        .call_getIncludedService = &call_getIncludedService,
        .call_getIncludedServices = &call_getIncludedServices,
        .call_removeEventListener = &call_removeEventListener,
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
        BluetoothRemoteGATTServiceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTServiceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_device) |cached| {
            return cached;
        }
        const value = BluetoothRemoteGATTServiceImpl.get_device(state);
        state.cached_device = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTServiceImpl.get_uuid(state);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothRemoteGATTServiceImpl.get_isPrimary(state);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTServiceImpl.get_oncharacteristicvaluechanged(state);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTServiceImpl.set_oncharacteristicvaluechanged(state, value);
    }

    pub fn get_onserviceadded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTServiceImpl.get_onserviceadded(state);
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTServiceImpl.set_onserviceadded(state, value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTServiceImpl.get_onservicechanged(state);
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTServiceImpl.set_onservicechanged(state, value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTServiceImpl.get_onserviceremoved(state);
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTServiceImpl.set_onserviceremoved(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getIncludedService(instance: *runtime.Instance, service: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_getIncludedService(state, service);
    }

    pub fn call_getCharacteristic(instance: *runtime.Instance, characteristic: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_getCharacteristic(state, characteristic);
    }

    pub fn call_getIncludedServices(instance: *runtime.Instance, service: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_getIncludedServices(state, service);
    }

    pub fn call_getCharacteristics(instance: *runtime.Instance, characteristic: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_getCharacteristics(state, characteristic);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTServiceImpl.call_addEventListener(state, type_, callback, options);
    }

};

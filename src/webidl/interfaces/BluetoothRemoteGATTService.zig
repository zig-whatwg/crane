//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTServiceImpl = @import("impls").BluetoothRemoteGATTService;
const EventTarget = @import("interfaces").EventTarget;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("interfaces").ServiceEventHandlers;
const Promise<sequence<BluetoothRemoteGATTCharacteristic>> = @import("interfaces").Promise<sequence<BluetoothRemoteGATTCharacteristic>>;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const UUID = @import("typedefs").UUID;
const BluetoothServiceUUID = @import("typedefs").BluetoothServiceUUID;
const BluetoothCharacteristicUUID = @import("typedefs").BluetoothCharacteristicUUID;
const Promise<BluetoothRemoteGATTCharacteristic> = @import("interfaces").Promise<BluetoothRemoteGATTCharacteristic>;
const Promise<sequence<BluetoothRemoteGATTService>> = @import("interfaces").Promise<sequence<BluetoothRemoteGATTService>>;
const Promise<BluetoothRemoteGATTService> = @import("interfaces").Promise<BluetoothRemoteGATTService>;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        BluetoothRemoteGATTServiceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTServiceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!BluetoothDevice {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTServiceImpl.get_device(instance);
        state.cached_device = value;
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

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothRemoteGATTServiceImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BluetoothRemoteGATTServiceImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BluetoothRemoteGATTServiceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getIncludedService(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTServiceImpl.call_getIncludedService(instance, service);
    }

    pub fn call_getCharacteristic(instance: *runtime.Instance, characteristic: BluetoothCharacteristicUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTServiceImpl.call_getCharacteristic(instance, characteristic);
    }

    pub fn call_getIncludedServices(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTServiceImpl.call_getIncludedServices(instance, service);
    }

    pub fn call_getCharacteristics(instance: *runtime.Instance, characteristic: BluetoothCharacteristicUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTServiceImpl.call_getCharacteristics(instance, characteristic);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothRemoteGATTServiceImpl.call_addEventListener(instance, type_, callback, options);
    }

};

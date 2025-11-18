//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTCharacteristicImpl = @import("impls").BluetoothRemoteGATTCharacteristic;
const EventTarget = @import("interfaces").EventTarget;
const CharacteristicEventHandlers = @import("interfaces").CharacteristicEventHandlers;
const UUID = @import("typedefs").UUID;
const BluetoothCharacteristicProperties = @import("interfaces").BluetoothCharacteristicProperties;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<BluetoothRemoteGATTDescriptor> = @import("interfaces").Promise<BluetoothRemoteGATTDescriptor>;
const Promise<BluetoothRemoteGATTCharacteristic> = @import("interfaces").Promise<BluetoothRemoteGATTCharacteristic>;
const BufferSource = @import("typedefs").BufferSource;
const DataView = @import("interfaces").DataView;
const BluetoothDescriptorUUID = @import("typedefs").BluetoothDescriptorUUID;
const BluetoothRemoteGATTService = @import("interfaces").BluetoothRemoteGATTService;
const Promise<sequence<BluetoothRemoteGATTDescriptor>> = @import("interfaces").Promise<sequence<BluetoothRemoteGATTDescriptor>>;
const Promise<DataView> = @import("interfaces").Promise<DataView>;
const EventHandler = @import("typedefs").EventHandler;

pub const BluetoothRemoteGATTCharacteristic = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTCharacteristic";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            CharacteristicEventHandlers,
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
            service: BluetoothRemoteGATTService = undefined,
            uuid: UUID = undefined,
            properties: BluetoothCharacteristicProperties = undefined,
            value: ?DataView = null,
            oncharacteristicvaluechanged: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothRemoteGATTCharacteristic, .{
        .deinit_fn = &deinit_wrapper,

        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_properties = &get_properties,
        .get_service = &get_service,
        .get_uuid = &get_uuid,
        .get_value = &get_value,

        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getDescriptor = &call_getDescriptor,
        .call_getDescriptors = &call_getDescriptors,
        .call_readValue = &call_readValue,
        .call_removeEventListener = &call_removeEventListener,
        .call_startNotifications = &call_startNotifications,
        .call_stopNotifications = &call_stopNotifications,
        .call_when = &call_when,
        .call_writeValue = &call_writeValue,
        .call_writeValueWithResponse = &call_writeValueWithResponse,
        .call_writeValueWithoutResponse = &call_writeValueWithoutResponse,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        BluetoothRemoteGATTCharacteristicImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTCharacteristicImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_service(instance: *runtime.Instance) anyerror!BluetoothRemoteGATTService {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_service) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTCharacteristicImpl.get_service(instance);
        state.cached_service = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTCharacteristicImpl.get_uuid(instance);
    }

    pub fn get_properties(instance: *runtime.Instance) anyerror!BluetoothCharacteristicProperties {
        return try BluetoothRemoteGATTCharacteristicImpl.get_properties(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.get_value(instance);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothRemoteGATTCharacteristicImpl.get_oncharacteristicvaluechanged(instance);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothRemoteGATTCharacteristicImpl.set_oncharacteristicvaluechanged(instance, value);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.call_readValue(instance);
    }

    pub fn call_startNotifications(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.call_startNotifications(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_when(instance, type_, options);
    }

    pub fn call_writeValueWithResponse(instance: *runtime.Instance, value: BufferSource) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithResponse(instance, value);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: BufferSource) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValue(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getDescriptors(instance: *runtime.Instance, descriptor: BluetoothDescriptorUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_getDescriptors(instance, descriptor);
    }

    pub fn call_getDescriptor(instance: *runtime.Instance, descriptor: BluetoothDescriptorUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_getDescriptor(instance, descriptor);
    }

    pub fn call_writeValueWithoutResponse(instance: *runtime.Instance, value: BufferSource) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithoutResponse(instance, value);
    }

    pub fn call_stopNotifications(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTCharacteristicImpl.call_stopNotifications(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BluetoothRemoteGATTCharacteristicImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

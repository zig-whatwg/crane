//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTCharacteristicImpl = @import("../impls/BluetoothRemoteGATTCharacteristic.zig");
const EventTarget = @import("EventTarget.zig");
const CharacteristicEventHandlers = @import("CharacteristicEventHandlers.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothRemoteGATTCharacteristicImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTCharacteristicImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_service(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_service) |cached| {
            return cached;
        }
        const value = BluetoothRemoteGATTCharacteristicImpl.get_service(state);
        state.cached_service = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.get_uuid(state);
    }

    pub fn get_properties(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.get_properties(state);
    }

    pub fn get_value(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.get_value(state);
    }

    pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.get_oncharacteristicvaluechanged(state);
    }

    pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothRemoteGATTCharacteristicImpl.set_oncharacteristicvaluechanged(state, value);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.call_readValue(state);
    }

    pub fn call_startNotifications(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.call_startNotifications(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_when(state, type_, options);
    }

    pub fn call_writeValueWithResponse(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithResponse(state, value);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_writeValue(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getDescriptors(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_getDescriptors(state, descriptor);
    }

    pub fn call_getDescriptor(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_getDescriptor(state, descriptor);
    }

    pub fn call_writeValueWithoutResponse(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithoutResponse(state, value);
    }

    pub fn call_stopNotifications(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothRemoteGATTCharacteristicImpl.call_stopNotifications(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothRemoteGATTCharacteristicImpl.call_removeEventListener(state, type_, callback, options);
    }

};

//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothAdvertisingEventImpl = @import("../impls/BluetoothAdvertisingEvent.zig");
const Event = @import("Event.zig");

pub const BluetoothAdvertisingEvent = struct {
    pub const Meta = struct {
        pub const name = "BluetoothAdvertisingEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            device: BluetoothDevice = undefined,
            uuids: FrozenArray<UUID> = undefined,
            name: ?runtime.DOMString = null,
            appearance: ?u16 = null,
            txPower: ?i8 = null,
            rssi: ?i8 = null,
            manufacturerData: BluetoothManufacturerDataMap = undefined,
            serviceData: BluetoothServiceDataMap = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothAdvertisingEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_appearance = &get_appearance,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_device = &get_device,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_manufacturerData = &get_manufacturerData,
        .get_name = &get_name,
        .get_returnValue = &get_returnValue,
        .get_rssi = &get_rssi,
        .get_serviceData = &get_serviceData,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_txPower = &get_txPower,
        .get_type = &get_type,
        .get_uuids = &get_uuids,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothAdvertisingEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothAdvertisingEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try BluetoothAdvertisingEventImpl.constructor(state, type_, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        BluetoothAdvertisingEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        BluetoothAdvertisingEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_timeStamp(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_device) |cached| {
            return cached;
        }
        const value = BluetoothAdvertisingEventImpl.get_device(state);
        state.cached_device = value;
        return value;
    }

    pub fn get_uuids(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_uuids(state);
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_name(state);
    }

    pub fn get_appearance(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_appearance(state);
    }

    pub fn get_txPower(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_txPower(state);
    }

    pub fn get_rssi(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.get_rssi(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_manufacturerData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_manufacturerData) |cached| {
            return cached;
        }
        const value = BluetoothAdvertisingEventImpl.get_manufacturerData(state);
        state.cached_manufacturerData = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceData) |cached| {
            return cached;
        }
        const value = BluetoothAdvertisingEventImpl.get_serviceData(state);
        state.cached_serviceData = value;
        return value;
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothAdvertisingEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.call_stopPropagation(state);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothAdvertisingEventImpl.call_preventDefault(state);
    }

};

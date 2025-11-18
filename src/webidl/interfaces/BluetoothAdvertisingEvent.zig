//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothAdvertisingEventImpl = @import("impls").BluetoothAdvertisingEvent;
const Event = @import("interfaces").Event;
const byte = @import("interfaces").byte;
const BluetoothServiceDataMap = @import("interfaces").BluetoothServiceDataMap;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const unsigned short = @import("interfaces").unsigned short;
const BluetoothManufacturerDataMap = @import("interfaces").BluetoothManufacturerDataMap;
const BluetoothAdvertisingEventInit = @import("dictionaries").BluetoothAdvertisingEventInit;
const FrozenArray<UUID> = @import("interfaces").FrozenArray<UUID>;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        BluetoothAdvertisingEventImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothAdvertisingEventImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: DOMString, init: BluetoothAdvertisingEventInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try BluetoothAdvertisingEventImpl.constructor(instance, type_, init);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothAdvertisingEventImpl.get_type(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_target(instance);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_srcElement(instance);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_currentTarget(instance);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) anyerror!u16 {
        return try BluetoothAdvertisingEventImpl.get_eventPhase(instance);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_cancelBubble(instance);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) anyerror!void {
        try BluetoothAdvertisingEventImpl.set_cancelBubble(instance, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_bubbles(instance);
    }

    pub fn get_cancelable(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_cancelable(instance);
    }

    pub fn get_returnValue(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_returnValue(instance);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) anyerror!void {
        try BluetoothAdvertisingEventImpl.set_returnValue(instance, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_defaultPrevented(instance);
    }

    pub fn get_composed(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_composed(instance);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothAdvertisingEventImpl.get_isTrusted(instance);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try BluetoothAdvertisingEventImpl.get_timeStamp(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!BluetoothDevice {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_device(instance);
        state.cached_device = value;
        return value;
    }

    pub fn get_uuids(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_uuids(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_name(instance);
    }

    pub fn get_appearance(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_appearance(instance);
    }

    pub fn get_txPower(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_txPower(instance);
    }

    pub fn get_rssi(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.get_rssi(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_manufacturerData(instance: *runtime.Instance) anyerror!BluetoothManufacturerDataMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_manufacturerData) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_manufacturerData(instance);
        state.cached_manufacturerData = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceData(instance: *runtime.Instance) anyerror!BluetoothServiceDataMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_serviceData) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_serviceData(instance);
        state.cached_serviceData = value;
        return value;
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyerror!void {
        return try BluetoothAdvertisingEventImpl.call_stopImmediatePropagation(instance);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: DOMString, bubbles: bool, cancelable: bool) anyerror!void {
        
        return try BluetoothAdvertisingEventImpl.call_initEvent(instance, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothAdvertisingEventImpl.call_composedPath(instance);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyerror!void {
        return try BluetoothAdvertisingEventImpl.call_stopPropagation(instance);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyerror!void {
        return try BluetoothAdvertisingEventImpl.call_preventDefault(instance);
    }

};

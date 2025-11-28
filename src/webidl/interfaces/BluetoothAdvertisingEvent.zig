//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothAdvertisingEventImpl = @import("impls").BluetoothAdvertisingEvent;
const Event = @import("interfaces").Event;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const BluetoothManufacturerDataMap = @import("interfaces").BluetoothManufacturerDataMap;
const UUID = @import("typedefs").UUID;
const EventTarget = @import("interfaces").EventTarget;
const BluetoothAdvertisingEventInit = @import("dictionaries").BluetoothAdvertisingEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;
const BluetoothServiceDataMap = @import("interfaces").BluetoothServiceDataMap;

pub const BluetoothAdvertisingEvent = struct {
    pub const Meta = struct {
        pub const name = "BluetoothAdvertisingEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "device", "get_device", null },
            .{ "uuids", "get_uuids", null },
            .{ "name", "get_name", null },
            .{ "appearance", "get_appearance", null },
            .{ "txPower", "get_txPower", null },
            .{ "rssi", "get_rssi", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "device", "get_device", null },
            .{ "uuids", "get_uuids", null },
            .{ "name", "get_name", null },
            .{ "appearance", "get_appearance", null },
            .{ "txPower", "get_txPower", null },
            .{ "rssi", "get_rssi", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            device: *runtime.Instance = undefined,
            uuids: runtime.FrozenArray(UUID) = undefined,
            name: ?runtime.DOMString = null,
            appearance: ?u16 = null,
            txPower: ?i8 = null,
            rssi: ?i8 = null,
            manufacturerData: *runtime.Instance = undefined,
            serviceData: *runtime.Instance = undefined,
            cached_device: ?*runtime.Instance = null,
            cached_manufacturerData: ?*runtime.Instance = null,
            cached_serviceData: ?*runtime.Instance = null,
            _internal: ?*BluetoothAdvertisingEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_appearance = &get_appearance,
        .get_device = &get_device,
        .get_manufacturerData = &get_manufacturerData,
        .get_name = &get_name,
        .get_rssi = &get_rssi,
        .get_serviceData = &get_serviceData,
        .get_txPower = &get_txPower,
        .get_uuids = &get_uuids,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothAdvertisingEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothAdvertisingEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, init_data: BluetoothAdvertisingEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BluetoothAdvertisingEventImpl.call_constructor(allocator, ctx, @"type", init_data);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_device(instance);
        state.own.cached_device = value;
        return value;
    }

    pub fn get_uuids(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothAdvertisingEventImpl.get_uuids(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?DOMString {
        return try BluetoothAdvertisingEventImpl.get_name(instance);
    }

    pub fn get_appearance(instance: *runtime.Instance) anyerror!?u16 {
        return try BluetoothAdvertisingEventImpl.get_appearance(instance);
    }

    pub fn get_txPower(instance: *runtime.Instance) anyerror!?i8 {
        return try BluetoothAdvertisingEventImpl.get_txPower(instance);
    }

    pub fn get_rssi(instance: *runtime.Instance) anyerror!?i8 {
        return try BluetoothAdvertisingEventImpl.get_rssi(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_manufacturerData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_manufacturerData) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_manufacturerData(instance);
        state.own.cached_manufacturerData = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serviceData) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_serviceData(instance);
        state.own.cached_serviceData = value;
        return value;
    }

};

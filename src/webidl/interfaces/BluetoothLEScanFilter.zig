//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothLEScanFilterImpl = @import("impls").BluetoothLEScanFilter;
const BluetoothManufacturerDataFilter = @import("interfaces").BluetoothManufacturerDataFilter;
const BluetoothLEScanFilterInit = @import("dictionaries").BluetoothLEScanFilterInit;
const UUID = @import("typedefs").UUID;
const DOMString = @import("typedefs").DOMString;
const BluetoothServiceDataFilter = @import("interfaces").BluetoothServiceDataFilter;

pub const BluetoothLEScanFilter = struct {
    pub const Meta = struct {
        pub const name = "BluetoothLEScanFilter";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: ?runtime.DOMString = null,
            namePrefix: ?runtime.DOMString = null,
            services: runtime.FrozenArray(UUID) = undefined,
            manufacturerData: BluetoothManufacturerDataFilter = undefined,
            serviceData: BluetoothServiceDataFilter = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothLEScanFilter, .{
        .deinit_fn = &deinit_wrapper,

        .get_manufacturerData = &get_manufacturerData,
        .get_name = &get_name,
        .get_namePrefix = &get_namePrefix,
        .get_serviceData = &get_serviceData,
        .get_services = &get_services,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return BluetoothLEScanFilterImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothLEScanFilterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init_data: BluetoothLEScanFilterInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try BluetoothLEScanFilterImpl.constructor(instance, init_data);
        
        return instance;
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothLEScanFilterImpl.get_name(instance);
    }

    pub fn get_namePrefix(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothLEScanFilterImpl.get_namePrefix(instance);
    }

    pub fn get_services(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothLEScanFilterImpl.get_services(instance);
    }

    pub fn get_manufacturerData(instance: *runtime.Instance) anyerror!BluetoothManufacturerDataFilter {
        return try BluetoothLEScanFilterImpl.get_manufacturerData(instance);
    }

    pub fn get_serviceData(instance: *runtime.Instance) anyerror!BluetoothServiceDataFilter {
        return try BluetoothLEScanFilterImpl.get_serviceData(instance);
    }

};

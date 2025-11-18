//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothLEScanFilterImpl = @import("../impls/BluetoothLEScanFilter.zig");

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
            services: FrozenArray<UUID> = undefined,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothLEScanFilterImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothLEScanFilterImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try BluetoothLEScanFilterImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanFilterImpl.get_name(state);
    }

    pub fn get_namePrefix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanFilterImpl.get_namePrefix(state);
    }

    pub fn get_services(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanFilterImpl.get_services(state);
    }

    pub fn get_manufacturerData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanFilterImpl.get_manufacturerData(state);
    }

    pub fn get_serviceData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanFilterImpl.get_serviceData(state);
    }

};

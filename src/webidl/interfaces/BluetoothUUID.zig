//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothUUIDImpl = @import("impls").BluetoothUUID;
const UUID = @import("typedefs").UUID;
const (DOMString or unsigned long) = @import("interfaces").(DOMString or unsigned long);

pub const BluetoothUUID = struct {
    pub const Meta = struct {
        pub const name = "BluetoothUUID";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothUUID, .{
        .deinit_fn = &deinit_wrapper,

        .call_canonicalUUID = &call_canonicalUUID,
        .call_getCharacteristic = &call_getCharacteristic,
        .call_getDescriptor = &call_getDescriptor,
        .call_getService = &call_getService,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        BluetoothUUIDImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothUUIDImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getService(instance: *runtime.Instance, name: anyopaque) anyerror!UUID {
        
        return try BluetoothUUIDImpl.call_getService(instance, name);
    }

    pub fn call_canonicalUUID(instance: *runtime.Instance, alias: u32) anyerror!UUID {
        // [EnforceRange] on alias
        if (!runtime.isInRange(alias)) return error.TypeError;
        
        return try BluetoothUUIDImpl.call_canonicalUUID(instance, alias);
    }

    pub fn call_getCharacteristic(instance: *runtime.Instance, name: anyopaque) anyerror!UUID {
        
        return try BluetoothUUIDImpl.call_getCharacteristic(instance, name);
    }

    pub fn call_getDescriptor(instance: *runtime.Instance, name: anyopaque) anyerror!UUID {
        
        return try BluetoothUUIDImpl.call_getDescriptor(instance, name);
    }

};

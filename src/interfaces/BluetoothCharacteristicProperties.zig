//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothCharacteristicPropertiesImpl = @import("../impls/BluetoothCharacteristicProperties.zig");

pub const BluetoothCharacteristicProperties = struct {
    pub const Meta = struct {
        pub const name = "BluetoothCharacteristicProperties";
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
            broadcast: bool = undefined,
            read: bool = undefined,
            writeWithoutResponse: bool = undefined,
            write: bool = undefined,
            notify: bool = undefined,
            indicate: bool = undefined,
            authenticatedSignedWrites: bool = undefined,
            reliableWrite: bool = undefined,
            writableAuxiliaries: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothCharacteristicProperties, .{
        .deinit_fn = &deinit_wrapper,

        .get_authenticatedSignedWrites = &get_authenticatedSignedWrites,
        .get_broadcast = &get_broadcast,
        .get_indicate = &get_indicate,
        .get_notify = &get_notify,
        .get_read = &get_read,
        .get_reliableWrite = &get_reliableWrite,
        .get_writableAuxiliaries = &get_writableAuxiliaries,
        .get_write = &get_write,
        .get_writeWithoutResponse = &get_writeWithoutResponse,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothCharacteristicPropertiesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothCharacteristicPropertiesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_broadcast(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_broadcast(state);
    }

    pub fn get_read(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_read(state);
    }

    pub fn get_writeWithoutResponse(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_writeWithoutResponse(state);
    }

    pub fn get_write(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_write(state);
    }

    pub fn get_notify(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_notify(state);
    }

    pub fn get_indicate(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_indicate(state);
    }

    pub fn get_authenticatedSignedWrites(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_authenticatedSignedWrites(state);
    }

    pub fn get_reliableWrite(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_reliableWrite(state);
    }

    pub fn get_writableAuxiliaries(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothCharacteristicPropertiesImpl.get_writableAuxiliaries(state);
    }

};

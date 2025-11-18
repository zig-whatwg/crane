//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothUUIDImpl = @import("../impls/BluetoothUUID.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothUUIDImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothUUIDImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getService(instance: *runtime.Instance, name: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothUUIDImpl.call_getService(state, name);
    }

    pub fn call_canonicalUUID(instance: *runtime.Instance, alias: u32) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on alias
        if (alias > std.math.maxInt(u53)) return error.TypeError;
        
        return BluetoothUUIDImpl.call_canonicalUUID(state, alias);
    }

    pub fn call_getCharacteristic(instance: *runtime.Instance, name: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothUUIDImpl.call_getCharacteristic(state, name);
    }

    pub fn call_getDescriptor(instance: *runtime.Instance, name: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BluetoothUUIDImpl.call_getDescriptor(state, name);
    }

};

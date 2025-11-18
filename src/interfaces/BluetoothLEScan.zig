//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothLEScanImpl = @import("../impls/BluetoothLEScan.zig");

pub const BluetoothLEScan = struct {
    pub const Meta = struct {
        pub const name = "BluetoothLEScan";
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
            filters: FrozenArray<BluetoothLEScanFilter> = undefined,
            keepRepeatedDevices: bool = undefined,
            acceptAllAdvertisements: bool = undefined,
            active: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothLEScan, .{
        .deinit_fn = &deinit_wrapper,

        .get_acceptAllAdvertisements = &get_acceptAllAdvertisements,
        .get_active = &get_active,
        .get_filters = &get_filters,
        .get_keepRepeatedDevices = &get_keepRepeatedDevices,

        .call_stop = &call_stop,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothLEScanImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothLEScanImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_filters(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanImpl.get_filters(state);
    }

    pub fn get_keepRepeatedDevices(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothLEScanImpl.get_keepRepeatedDevices(state);
    }

    pub fn get_acceptAllAdvertisements(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothLEScanImpl.get_acceptAllAdvertisements(state);
    }

    pub fn get_active(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BluetoothLEScanImpl.get_active(state);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothLEScanImpl.call_stop(state);
    }

};

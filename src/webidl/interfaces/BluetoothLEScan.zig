//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothLEScanImpl = @import("impls").BluetoothLEScan;
const FrozenArray<BluetoothLEScanFilter> = @import("interfaces").FrozenArray<BluetoothLEScanFilter>;

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
        
        // Initialize the instance (Impl receives full instance)
        BluetoothLEScanImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothLEScanImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_filters(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothLEScanImpl.get_filters(instance);
    }

    pub fn get_keepRepeatedDevices(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothLEScanImpl.get_keepRepeatedDevices(instance);
    }

    pub fn get_acceptAllAdvertisements(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothLEScanImpl.get_acceptAllAdvertisements(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothLEScanImpl.get_active(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try BluetoothLEScanImpl.call_stop(instance);
    }

};

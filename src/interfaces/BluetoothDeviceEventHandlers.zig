//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothDeviceEventHandlersImpl = @import("../impls/BluetoothDeviceEventHandlers.zig");

pub const BluetoothDeviceEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDeviceEventHandlers";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onadvertisementreceived: EventHandler = undefined,
            ongattserverdisconnected: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothDeviceEventHandlers, .{
        .deinit_fn = &deinit_wrapper,

        .get_onadvertisementreceived = &get_onadvertisementreceived,
        .get_ongattserverdisconnected = &get_ongattserverdisconnected,

        .set_onadvertisementreceived = &set_onadvertisementreceived,
        .set_ongattserverdisconnected = &set_ongattserverdisconnected,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        BluetoothDeviceEventHandlersImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BluetoothDeviceEventHandlersImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceEventHandlersImpl.get_onadvertisementreceived(state);
    }

    pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceEventHandlersImpl.set_onadvertisementreceived(state, value);
    }

    pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BluetoothDeviceEventHandlersImpl.get_ongattserverdisconnected(state);
    }

    pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BluetoothDeviceEventHandlersImpl.set_ongattserverdisconnected(state, value);
    }

};

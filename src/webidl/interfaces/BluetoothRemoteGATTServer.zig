//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTServerImpl = @import("impls").BluetoothRemoteGATTServer;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const Promise<BluetoothRemoteGATTServer> = @import("interfaces").Promise<BluetoothRemoteGATTServer>;
const Promise<sequence<BluetoothRemoteGATTService>> = @import("interfaces").Promise<sequence<BluetoothRemoteGATTService>>;
const Promise<BluetoothRemoteGATTService> = @import("interfaces").Promise<BluetoothRemoteGATTService>;
const BluetoothServiceUUID = @import("typedefs").BluetoothServiceUUID;

pub const BluetoothRemoteGATTServer = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTServer";
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
            device: BluetoothDevice = undefined,
            connected: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BluetoothRemoteGATTServer, .{
        .deinit_fn = &deinit_wrapper,

        .get_connected = &get_connected,
        .get_device = &get_device,

        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,
        .call_getPrimaryService = &call_getPrimaryService,
        .call_getPrimaryServices = &call_getPrimaryServices,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        BluetoothRemoteGATTServerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTServerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!BluetoothDevice {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTServerImpl.get_device(instance);
        state.cached_device = value;
        return value;
    }

    pub fn get_connected(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothRemoteGATTServerImpl.get_connected(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try BluetoothRemoteGATTServerImpl.call_disconnect(instance);
    }

    pub fn call_getPrimaryServices(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTServerImpl.call_getPrimaryServices(instance, service);
    }

    pub fn call_connect(instance: *runtime.Instance) anyerror!anyopaque {
        return try BluetoothRemoteGATTServerImpl.call_connect(instance);
    }

    pub fn call_getPrimaryService(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!anyopaque {
        
        return try BluetoothRemoteGATTServerImpl.call_getPrimaryService(instance, service);
    }

};

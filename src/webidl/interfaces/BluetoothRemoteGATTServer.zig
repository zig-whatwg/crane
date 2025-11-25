//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-25T13:07:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTServerImpl = @import("impls").BluetoothRemoteGATTServer;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const BluetoothRemoteGATTService = @import("interfaces").BluetoothRemoteGATTService;
const BluetoothServiceUUID = @import("typedefs").BluetoothServiceUUID;

pub const BluetoothRemoteGATTServer = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTServer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "connected", "get_connected", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "connect", "call_connect", 0 },
            .{ "disconnect", "call_disconnect", 0 },
            .{ "getPrimaryService", "call_getPrimaryService", 1 },
            .{ "getPrimaryServices", "call_getPrimaryServices", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "connect",
            "disconnect",
            "getPrimaryService",
            "getPrimaryServices",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "device", "get_device", null },
            .{ "connected", "get_connected", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            device: *runtime.Instance = undefined,
            connected: bool = undefined,
            cached_device: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTServerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_connected = &get_connected,
        .get_device = &get_device,

        .call_connect = &call_connect,
        .call_disconnect = &call_disconnect,
        .call_getPrimaryService = &call_getPrimaryService,
        .call_getPrimaryServices = &call_getPrimaryServices,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothRemoteGATTServerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTServerImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTServerImpl.get_device(instance);
        state.own.cached_device = value;
        return value;
    }

    pub fn get_connected(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothRemoteGATTServerImpl.get_connected(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try BluetoothRemoteGATTServerImpl.call_disconnect(instance);
    }

    pub fn call_getPrimaryServices(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTServerImpl.call_getPrimaryServices(instance, service);
    }

    pub fn call_connect(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTServerImpl.call_connect(instance);
    }

    pub fn call_getPrimaryService(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTServerImpl.call_getPrimaryService(instance, service);
    }

};

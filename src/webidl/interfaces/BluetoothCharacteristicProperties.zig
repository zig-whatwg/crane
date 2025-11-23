//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothCharacteristicPropertiesImpl = @import("impls").BluetoothCharacteristicProperties;

pub const BluetoothCharacteristicProperties = struct {
    pub const Meta = struct {
        pub const name = "BluetoothCharacteristicProperties";
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
            .{ "broadcast", "get_broadcast", null },
            .{ "read", "get_read", null },
            .{ "writeWithoutResponse", "get_writeWithoutResponse", null },
            .{ "write", "get_write", null },
            .{ "notify", "get_notify", null },
            .{ "indicate", "get_indicate", null },
            .{ "authenticatedSignedWrites", "get_authenticatedSignedWrites", null },
            .{ "reliableWrite", "get_reliableWrite", null },
            .{ "writableAuxiliaries", "get_writableAuxiliaries", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "broadcast", "get_broadcast", null },
            .{ "read", "get_read", null },
            .{ "writeWithoutResponse", "get_writeWithoutResponse", null },
            .{ "write", "get_write", null },
            .{ "notify", "get_notify", null },
            .{ "indicate", "get_indicate", null },
            .{ "authenticatedSignedWrites", "get_authenticatedSignedWrites", null },
            .{ "reliableWrite", "get_reliableWrite", null },
            .{ "writableAuxiliaries", "get_writableAuxiliaries", null },
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
            broadcast: bool = undefined,
            read: bool = undefined,
            writeWithoutResponse: bool = undefined,
            write: bool = undefined,
            notify: bool = undefined,
            indicate: bool = undefined,
            authenticatedSignedWrites: bool = undefined,
            reliableWrite: bool = undefined,
            writableAuxiliaries: bool = undefined,
            _internal: ?*BluetoothCharacteristicPropertiesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_authenticatedSignedWrites = &get_authenticatedSignedWrites,
        .get_broadcast = &get_broadcast,
        .get_indicate = &get_indicate,
        .get_notify = &get_notify,
        .get_read = &get_read,
        .get_reliableWrite = &get_reliableWrite,
        .get_writableAuxiliaries = &get_writableAuxiliaries,
        .get_write = &get_write,
        .get_writeWithoutResponse = &get_writeWithoutResponse,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothCharacteristicPropertiesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothCharacteristicPropertiesImpl.deinit(instance);
    }

    pub fn get_broadcast(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_broadcast(instance);
    }

    pub fn get_read(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_read(instance);
    }

    pub fn get_writeWithoutResponse(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_writeWithoutResponse(instance);
    }

    pub fn get_write(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_write(instance);
    }

    pub fn get_notify(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_notify(instance);
    }

    pub fn get_indicate(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_indicate(instance);
    }

    pub fn get_authenticatedSignedWrites(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_authenticatedSignedWrites(instance);
    }

    pub fn get_reliableWrite(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_reliableWrite(instance);
    }

    pub fn get_writableAuxiliaries(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothCharacteristicPropertiesImpl.get_writableAuxiliaries(instance);
    }

};

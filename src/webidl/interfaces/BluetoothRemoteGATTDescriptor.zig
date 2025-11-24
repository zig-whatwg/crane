//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-24T18:47:06Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTDescriptorImpl = @import("impls").BluetoothRemoteGATTDescriptor;
const BluetoothRemoteGATTCharacteristic = @import("interfaces").BluetoothRemoteGATTCharacteristic;
const UUID = @import("typedefs").UUID;
const BufferSource = @import("typedefs").BufferSource;

pub const BluetoothRemoteGATTDescriptor = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTDescriptor";
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
            .{ "characteristic", "get_characteristic", null },
            .{ "uuid", "get_uuid", null },
            .{ "value", "get_value", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "readValue", "call_readValue", 0 },
            .{ "writeValue", "call_writeValue", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "readValue",
            "writeValue",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "characteristic", "get_characteristic", null },
            .{ "uuid", "get_uuid", null },
            .{ "value", "get_value", null },
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
            characteristic: *runtime.Instance = undefined,
            uuid: UUID = undefined,
            value: ?runtime.DataView = null,
            cached_characteristic: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTDescriptorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_characteristic = &get_characteristic,
        .get_uuid = &get_uuid,
        .get_value = &get_value,

        .call_readValue = &call_readValue,
        .call_writeValue = &call_writeValue,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothRemoteGATTDescriptorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothRemoteGATTDescriptorImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_characteristic(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_characteristic) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTDescriptorImpl.get_characteristic(instance);
        state.own.cached_characteristic = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTDescriptorImpl.get_uuid(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTDescriptorImpl.get_value(instance);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: BufferSource) anyerror!*const anyopaque {
        
        return try BluetoothRemoteGATTDescriptorImpl.call_writeValue(instance, value);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothRemoteGATTDescriptorImpl.call_readValue(instance);
    }

};

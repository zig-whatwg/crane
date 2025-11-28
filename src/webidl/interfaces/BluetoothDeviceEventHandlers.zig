//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothDeviceEventHandlersImpl = @import("impls").BluetoothDeviceEventHandlers;
const mixins = @import("mixins");
const EventHandler = @import("typedefs").EventHandler;

pub const BluetoothDeviceEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDeviceEventHandlers";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
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
            onadvertisementreceived: EventHandler = undefined,
            ongattserverdisconnected: EventHandler = undefined,
            _internal: ?*BluetoothDeviceEventHandlersImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onadvertisementreceived = &get_onadvertisementreceived,
        .get_ongattserverdisconnected = &get_ongattserverdisconnected,

        .set_onadvertisementreceived = &set_onadvertisementreceived,
        .set_ongattserverdisconnected = &set_ongattserverdisconnected,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothDeviceEventHandlersImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothDeviceEventHandlersImpl.deinit(instance);
    }

    pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceEventHandlersImpl.get_onadvertisementreceived(instance);
    }

    pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceEventHandlersImpl.set_onadvertisementreceived(instance, value);
    }

    pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try BluetoothDeviceEventHandlersImpl.get_ongattserverdisconnected(instance);
    }

    pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BluetoothDeviceEventHandlersImpl.set_ongattserverdisconnected(instance, value);
    }

};

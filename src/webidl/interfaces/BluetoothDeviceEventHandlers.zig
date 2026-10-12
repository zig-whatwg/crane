//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothDeviceEventHandlersImpl = @import("impls").BluetoothDeviceEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const BluetoothDeviceEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDeviceEventHandlers";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onadvertisementreceived: typedefs.EventHandler = undefined,
            ongattserverdisconnected: typedefs.EventHandler = undefined,
            _internal: ?*BluetoothDeviceEventHandlersImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothDeviceEventHandlers")) {
            if (comptime @hasDecl(impls.BluetoothDeviceEventHandlers, "installHooks")) impls.BluetoothDeviceEventHandlers.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BluetoothDeviceEventHandlersImpl, "get_onadvertisementreceived")) return try BluetoothDeviceEventHandlersImpl.get_onadvertisementreceived(instance);
        return event_handlers.value(EventHandler, instance, "onadvertisementreceived");
    }

    pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BluetoothDeviceEventHandlersImpl, "set_onadvertisementreceived")) return try BluetoothDeviceEventHandlersImpl.set_onadvertisementreceived(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onadvertisementreceived", value);
    }

    pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BluetoothDeviceEventHandlersImpl, "get_ongattserverdisconnected")) return try BluetoothDeviceEventHandlersImpl.get_ongattserverdisconnected(instance);
        return event_handlers.value(EventHandler, instance, "ongattserverdisconnected");
    }

    pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BluetoothDeviceEventHandlersImpl, "set_ongattserverdisconnected")) return try BluetoothDeviceEventHandlersImpl.set_ongattserverdisconnected(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ongattserverdisconnected", value);
    }
};

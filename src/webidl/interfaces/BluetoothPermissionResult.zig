//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothPermissionResultImpl = @import("impls").BluetoothPermissionResult;
const PermissionStatus = @import("interfaces").PermissionStatus;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const PermissionState = @import("enums").PermissionState;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const BluetoothPermissionResult = struct {
    pub const Meta = struct {
        pub const name = "BluetoothPermissionResult";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PermissionStatus;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "devices", "get_devices", "set_devices" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "devices", "get_devices", "set_devices" },
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
            devices: runtime.FrozenArray(BluetoothDevice) = undefined,
            _internal: ?*BluetoothPermissionResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_devices = &get_devices,

        .set_devices = &set_devices,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothPermissionResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothPermissionResultImpl.deinit(instance);
    }

    pub fn get_devices(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothPermissionResultImpl.get_devices(instance);
    }

    pub fn set_devices(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try BluetoothPermissionResultImpl.set_devices(instance, value);
    }

};

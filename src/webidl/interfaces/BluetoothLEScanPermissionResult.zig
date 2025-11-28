//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothLEScanPermissionResultImpl = @import("impls").BluetoothLEScanPermissionResult;
const mixins = @import("mixins");
const PermissionStatus = @import("interfaces").PermissionStatus;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PermissionState = @import("enums").PermissionState;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const BluetoothLEScan = @import("interfaces").BluetoothLEScan;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const BluetoothLEScanPermissionResult = struct {
    pub const Meta = struct {
        pub const name = "BluetoothLEScanPermissionResult";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PermissionStatus;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "scans", "get_scans", "set_scans" },
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
            .{ "scans", "get_scans", "set_scans" },
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
            scans: runtime.FrozenArray(BluetoothLEScan) = undefined,
            _internal: ?*BluetoothLEScanPermissionResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_scans = &get_scans,

        .set_scans = &set_scans,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothLEScanPermissionResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothLEScanPermissionResultImpl.deinit(instance);
    }

    pub fn get_scans(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothLEScanPermissionResultImpl.get_scans(instance);
    }

    pub fn set_scans(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try BluetoothLEScanPermissionResultImpl.set_scans(instance, value);
    }

};

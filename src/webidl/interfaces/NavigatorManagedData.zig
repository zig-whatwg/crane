//! Generated from: managed-configuration.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorManagedDataImpl = @import("impls").NavigatorManagedData;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const NavigatorManagedData = struct {
    pub const Meta = struct {
        pub const name = "NavigatorManagedData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onmanagedconfigurationchange", "get_onmanagedconfigurationchange", "set_onmanagedconfigurationchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getManagedConfiguration", "call_getManagedConfiguration", 1 },
            .{ "getAnnotatedAssetId", "call_getAnnotatedAssetId", 0 },
            .{ "getAnnotatedLocation", "call_getAnnotatedLocation", 0 },
            .{ "getDirectoryId", "call_getDirectoryId", 0 },
            .{ "getHostname", "call_getHostname", 0 },
            .{ "getSerialNumber", "call_getSerialNumber", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getManagedConfiguration",
            "getAnnotatedAssetId",
            "getAnnotatedLocation",
            "getDirectoryId",
            "getHostname",
            "getSerialNumber",
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
            .{ "onmanagedconfigurationchange", "get_onmanagedconfigurationchange", "set_onmanagedconfigurationchange" },
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
            onmanagedconfigurationchange: EventHandler = undefined,
            _internal: ?*NavigatorManagedDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onmanagedconfigurationchange = &get_onmanagedconfigurationchange,

        .set_onmanagedconfigurationchange = &set_onmanagedconfigurationchange,

        .call_getAnnotatedAssetId = &call_getAnnotatedAssetId,
        .call_getAnnotatedLocation = &call_getAnnotatedLocation,
        .call_getDirectoryId = &call_getDirectoryId,
        .call_getHostname = &call_getHostname,
        .call_getManagedConfiguration = &call_getManagedConfiguration,
        .call_getSerialNumber = &call_getSerialNumber,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorManagedDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorManagedDataImpl.deinit(instance);
    }

    pub fn get_onmanagedconfigurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigatorManagedDataImpl.get_onmanagedconfigurationchange(instance);
    }

    pub fn set_onmanagedconfigurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigatorManagedDataImpl.set_onmanagedconfigurationchange(instance, value);
    }

    pub fn call_getManagedConfiguration(instance: *runtime.Instance, keys: *const anyopaque) anyerror!*const anyopaque {
        
        return try NavigatorManagedDataImpl.call_getManagedConfiguration(instance, keys);
    }

    pub fn call_getHostname(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorManagedDataImpl.call_getHostname(instance);
    }

    pub fn call_getAnnotatedAssetId(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorManagedDataImpl.call_getAnnotatedAssetId(instance);
    }

    pub fn call_getDirectoryId(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorManagedDataImpl.call_getDirectoryId(instance);
    }

    pub fn call_getAnnotatedLocation(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorManagedDataImpl.call_getAnnotatedLocation(instance);
    }

    pub fn call_getSerialNumber(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try NavigatorManagedDataImpl.call_getSerialNumber(instance);
    }

};

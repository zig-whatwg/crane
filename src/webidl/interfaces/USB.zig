//! Generated from: webusb.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBImpl = @import("impls").USB;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const USBDeviceRequestOptions = @import("dictionaries").USBDeviceRequestOptions;
const DOMString = @import("typedefs").DOMString;
const USBDevice = @import("interfaces").USBDevice;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const Event = @import("interfaces").Event;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const USB = struct {
    pub const Meta = struct {
        pub const name = "USB";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getDevices", "call_getDevices", 0 },
            .{ "requestDevice", "call_requestDevice", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getDevices",
            "requestDevice",
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
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
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
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
            _internal: ?*USBImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_getDevices = &call_getDevices,
        .call_requestDevice = &call_requestDevice,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBImpl.deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try USBImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try USBImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try USBImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try USBImpl.set_ondisconnect(instance, value);
    }

    pub fn call_getDevices(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try USBImpl.call_getDevices(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestDevice(instance: *runtime.Instance, options: USBDeviceRequestOptions) anyerror!*const anyopaque {
        
        return try USBImpl.call_requestDevice(instance, options);
    }

};

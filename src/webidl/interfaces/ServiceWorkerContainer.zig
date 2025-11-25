//! Generated from: service-workers.idl
//! Generated at: 2025-11-25T14:21:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerContainerImpl = @import("impls").ServiceWorkerContainer;
const EventTarget = @import("interfaces").EventTarget;
const ServiceWorker = @import("interfaces").ServiceWorker;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const USVString = @import("interfaces").USVString;
const Observable = @import("interfaces").Observable;
const ServiceWorkerRegistration = @import("interfaces").ServiceWorkerRegistration;
const Event = @import("interfaces").Event;
const RegistrationOptions = @import("dictionaries").RegistrationOptions;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const ServiceWorkerContainer = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerContainer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "controller", "get_controller", null },
            .{ "ready", "get_ready", null },
            .{ "oncontrollerchange", "get_oncontrollerchange", "set_oncontrollerchange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "register", "call_register", 1 },
            .{ "getRegistration", "call_getRegistration", 0 },
            .{ "getRegistrations", "call_getRegistrations", 0 },
            .{ "startMessages", "call_startMessages", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
            "getRegistration",
            "getRegistrations",
            "startMessages",
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
            .{ "controller", "get_controller", null },
            .{ "ready", "get_ready", null },
            .{ "oncontrollerchange", "get_oncontrollerchange", "set_oncontrollerchange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
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
            controller: ?*runtime.Instance = null,
            ready: runtime.Promise(ServiceWorkerRegistration) = undefined,
            oncontrollerchange: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            _internal: ?*ServiceWorkerContainerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_controller = &get_controller,
        .get_oncontrollerchange = &get_oncontrollerchange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_ready = &get_ready,

        .set_oncontrollerchange = &set_oncontrollerchange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_getRegistration = &call_getRegistration,
        .call_getRegistrations = &call_getRegistrations,
        .call_register = &call_register,
        .call_startMessages = &call_startMessages,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ServiceWorkerContainerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerContainerImpl.deinit(instance);
    }

    pub fn get_controller(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ServiceWorkerContainerImpl.get_controller(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ServiceWorkerContainerImpl.get_ready(instance);
    }

    pub fn get_oncontrollerchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerContainerImpl.get_oncontrollerchange(instance);
    }

    pub fn set_oncontrollerchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerContainerImpl.set_oncontrollerchange(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerContainerImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerContainerImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerContainerImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerContainerImpl.set_onmessageerror(instance, value);
    }

    pub fn call_startMessages(instance: *runtime.Instance) anyerror!void {
        return try ServiceWorkerContainerImpl.call_startMessages(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistrations(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerContainerImpl.call_getRegistrations(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistration(instance: *runtime.Instance, clientURL: runtime.USVString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ServiceWorkerContainerImpl.call_getRegistration(instance, clientURL);
    }

    /// Extended attributes: [NewObject]
    pub fn call_register(instance: *runtime.Instance, scriptURL: *const anyopaque, options: RegistrationOptions) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ServiceWorkerContainerImpl.call_register(instance, scriptURL, options);
    }

};

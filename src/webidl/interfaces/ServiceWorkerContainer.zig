//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerContainerImpl = @import("impls").ServiceWorkerContainer;
const EventTarget = @import("interfaces").EventTarget;
const ServiceWorker = @import("interfaces").ServiceWorker;
const Promise<FrozenArray<ServiceWorkerRegistration>> = @import("interfaces").Promise<FrozenArray<ServiceWorkerRegistration>>;
const RegistrationOptions = @import("dictionaries").RegistrationOptions;
const (TrustedScriptURL or USVString) = @import("interfaces").(TrustedScriptURL or USVString);
const Promise<ServiceWorkerRegistration> = @import("interfaces").Promise<ServiceWorkerRegistration>;
const Promise<(ServiceWorkerRegistrationorundefined)> = @import("interfaces").Promise<(ServiceWorkerRegistrationorundefined)>;
const EventHandler = @import("typedefs").EventHandler;

pub const ServiceWorkerContainer = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerContainer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            controller: ?ServiceWorker = null,
            ready: Promise<ServiceWorkerRegistration> = undefined,
            oncontrollerchange: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ServiceWorkerContainer, .{
        .deinit_fn = &deinit_wrapper,

        .get_controller = &get_controller,
        .get_oncontrollerchange = &get_oncontrollerchange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_ready = &get_ready,

        .set_oncontrollerchange = &set_oncontrollerchange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getRegistration = &call_getRegistration,
        .call_getRegistrations = &call_getRegistrations,
        .call_register = &call_register,
        .call_removeEventListener = &call_removeEventListener,
        .call_startMessages = &call_startMessages,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ServiceWorkerContainerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerContainerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_controller(instance: *runtime.Instance) anyerror!anyopaque {
        return try ServiceWorkerContainerImpl.get_controller(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerContainerImpl.call_removeEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistrations(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerContainerImpl.call_getRegistrations(instance);
    }

    pub fn call_startMessages(instance: *runtime.Instance) anyerror!void {
        return try ServiceWorkerContainerImpl.call_startMessages(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ServiceWorkerContainerImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistration(instance: *runtime.Instance, clientURL: runtime.USVString) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ServiceWorkerContainerImpl.call_getRegistration(instance, clientURL);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ServiceWorkerContainerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerContainerImpl.call_addEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_register(instance: *runtime.Instance, scriptURL: anyopaque, options: RegistrationOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try ServiceWorkerContainerImpl.call_register(instance, scriptURL, options);
    }

};

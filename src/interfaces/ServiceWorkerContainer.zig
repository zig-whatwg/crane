//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerContainerImpl = @import("../impls/ServiceWorkerContainer.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ServiceWorkerContainerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ServiceWorkerContainerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_controller(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerContainerImpl.get_controller(state);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerContainerImpl.get_ready(state);
    }

    pub fn get_oncontrollerchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerContainerImpl.get_oncontrollerchange(state);
    }

    pub fn set_oncontrollerchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerContainerImpl.set_oncontrollerchange(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerContainerImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerContainerImpl.set_onmessage(state, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerContainerImpl.get_onmessageerror(state);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerContainerImpl.set_onmessageerror(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerContainerImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistrations(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return ServiceWorkerContainerImpl.call_getRegistrations(state);
    }

    pub fn call_startMessages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerContainerImpl.call_startMessages(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerContainerImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistration(instance: *runtime.Instance, clientURL: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ServiceWorkerContainerImpl.call_getRegistration(state, clientURL);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ServiceWorkerContainerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerContainerImpl.call_addEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_register(instance: *runtime.Instance, scriptURL: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ServiceWorkerContainerImpl.call_register(state, scriptURL, options);
    }

};

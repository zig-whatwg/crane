//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerImpl = @import("../impls/ServiceWorker.zig");
const EventTarget = @import("EventTarget.zig");
const AbstractWorker = @import("AbstractWorker.zig");

pub const ServiceWorker = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorker";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            AbstractWorker,
        };
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
            scriptURL: runtime.USVString = undefined,
            state: ServiceWorkerState = undefined,
            onstatechange: EventHandler = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ServiceWorker, .{
        .deinit_fn = &deinit_wrapper,

        .get_onerror = &get_onerror,
        .get_onstatechange = &get_onstatechange,
        .get_scriptURL = &get_scriptURL,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_postMessage = &call_postMessage,
        .call_postMessage = &call_postMessage,
        .call_removeEventListener = &call_removeEventListener,
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
        ServiceWorkerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ServiceWorkerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_scriptURL(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return ServiceWorkerImpl.get_scriptURL(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerImpl.get_state(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerImpl.set_onstatechange(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceWorkerImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceWorkerImpl.set_onerror(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ServiceWorkerImpl.call_dispatchEvent(state, event);
    }

    /// Arguments for postMessage (WebIDL overloading)
    pub const PostMessageArgs = union(enum) {
        /// postMessage(message, transfer)
        any_sequence: struct {
            message: anyopaque,
            transfer: anyopaque,
        },
        /// postMessage(message, options)
        any_StructuredSerializeOptions: struct {
            message: anyopaque,
            options: anyopaque,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .any_sequence => |a| return ServiceWorkerImpl.any_sequence(state, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return ServiceWorkerImpl.any_StructuredSerializeOptions(state, a.message, a.options),
        }
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ServiceWorkerImpl.call_removeEventListener(state, type_, callback, options);
    }

};

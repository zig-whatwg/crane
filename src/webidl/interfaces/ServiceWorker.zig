//! Generated from: service-workers.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceWorkerImpl = @import("impls").ServiceWorker;
const EventTarget = @import("interfaces").EventTarget;
const AbstractWorker = @import("interfaces").AbstractWorker;
const ServiceWorkerState = @import("enums").ServiceWorkerState;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        ServiceWorkerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ServiceWorkerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_scriptURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ServiceWorkerImpl.get_scriptURL(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!ServiceWorkerState {
        return try ServiceWorkerImpl.get_state(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerImpl.set_onstatechange(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerImpl.set_onerror(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ServiceWorkerImpl.call_dispatchEvent(instance, event);
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
            options: StructuredSerializeOptions,
        },
    };

    pub fn call_postMessage(instance: *runtime.Instance, args: PostMessageArgs) anyerror!void {
        switch (args) {
            .any_sequence => |a| return try ServiceWorkerImpl.any_sequence(instance, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return try ServiceWorkerImpl.any_StructuredSerializeOptions(instance, a.message, a.options),
        }
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ServiceWorkerImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ServiceWorkerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

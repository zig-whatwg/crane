//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkerImpl = @import("../impls/Worker.zig");
const EventTarget = @import("EventTarget.zig");
const AbstractWorker = @import("AbstractWorker.zig");
const MessageEventTarget = @import("MessageEventTarget.zig");

pub const Worker = struct {
    pub const Meta = struct {
        pub const name = "Worker";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            AbstractWorker,
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onerror: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Worker, .{
        .deinit_fn = &deinit_wrapper,

        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_postMessage = &call_postMessage,
        .call_postMessage = &call_postMessage,
        .call_removeEventListener = &call_removeEventListener,
        .call_terminate = &call_terminate,
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
        WorkerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WorkerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, scriptURL: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try WorkerImpl.constructor(state, scriptURL, options);
        
        return instance;
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WorkerImpl.set_onerror(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WorkerImpl.set_onmessage(state, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerImpl.get_onmessageerror(state);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WorkerImpl.set_onmessageerror(state, value);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WorkerImpl.call_terminate(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WorkerImpl.call_when(state, type_, options);
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
            .any_sequence => |a| return WorkerImpl.any_sequence(state, a.message, a.transfer),
            .any_StructuredSerializeOptions => |a| return WorkerImpl.any_StructuredSerializeOptions(state, a.message, a.options),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return WorkerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WorkerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WorkerImpl.call_removeEventListener(state, type_, callback, options);
    }

};

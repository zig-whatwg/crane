//! Generated from: xhr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLHttpRequestEventTargetImpl = @import("../impls/XMLHttpRequestEventTarget.zig");
const EventTarget = @import("EventTarget.zig");

pub const XMLHttpRequestEventTarget = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequestEventTarget";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
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
            onloadstart: EventHandler = undefined,
            onprogress: EventHandler = undefined,
            onabort: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onload: EventHandler = undefined,
            ontimeout: EventHandler = undefined,
            onloadend: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XMLHttpRequestEventTarget, .{
        .deinit_fn = &deinit_wrapper,

        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onload = &get_onload,
        .get_onloadend = &get_onloadend,
        .get_onloadstart = &get_onloadstart,
        .get_onprogress = &get_onprogress,
        .get_ontimeout = &get_ontimeout,

        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onload = &set_onload,
        .set_onloadend = &set_onloadend,
        .set_onloadstart = &set_onloadstart,
        .set_onprogress = &set_onprogress,
        .set_ontimeout = &set_ontimeout,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        XMLHttpRequestEventTargetImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_onloadstart(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_onprogress(state, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_onabort(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_onerror(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_onload(state, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_ontimeout(state);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_ontimeout(state, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestEventTargetImpl.get_onloadend(state);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestEventTargetImpl.set_onloadend(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLHttpRequestEventTargetImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestEventTargetImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestEventTargetImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestEventTargetImpl.call_removeEventListener(state, type_, callback, options);
    }

};

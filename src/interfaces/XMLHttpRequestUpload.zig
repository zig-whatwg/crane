//! Generated from: xhr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLHttpRequestUploadImpl = @import("../impls/XMLHttpRequestUpload.zig");
const XMLHttpRequestEventTarget = @import("XMLHttpRequestEventTarget.zig");

pub const XMLHttpRequestUpload = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequestUpload";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XMLHttpRequestEventTarget;
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XMLHttpRequestUpload, .{
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
        XMLHttpRequestUploadImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_onloadstart(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_onprogress(state, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_onabort(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_onerror(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_onload(state, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_ontimeout(state);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_ontimeout(state, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestUploadImpl.get_onloadend(state);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestUploadImpl.set_onloadend(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLHttpRequestUploadImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestUploadImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestUploadImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestUploadImpl.call_removeEventListener(state, type_, callback, options);
    }

};

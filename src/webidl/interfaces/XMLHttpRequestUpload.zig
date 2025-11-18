//! Generated from: xhr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLHttpRequestUploadImpl = @import("impls").XMLHttpRequestUpload;
const XMLHttpRequestEventTarget = @import("interfaces").XMLHttpRequestEventTarget;

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
        
        // Initialize the instance (Impl receives full instance)
        XMLHttpRequestUploadImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLHttpRequestUploadImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onloadstart(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onprogress(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onabort(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onerror(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onload(instance, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_ontimeout(instance);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_ontimeout(instance, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestUploadImpl.get_onloadend(instance);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestUploadImpl.set_onloadend(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XMLHttpRequestUploadImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XMLHttpRequestUploadImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XMLHttpRequestUploadImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XMLHttpRequestUploadImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

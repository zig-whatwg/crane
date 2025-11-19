//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CloseWatcherImpl = @import("impls").CloseWatcher;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const CloseWatcherOptions = @import("dictionaries").CloseWatcherOptions;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const CloseWatcher = struct {
    pub const Meta = struct {
        pub const name = "CloseWatcher";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            oncancel: EventHandler = undefined,
            onclose: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CloseWatcher, .{
        .deinit_fn = &deinit_wrapper,

        .get_oncancel = &get_oncancel,
        .get_onclose = &get_onclose,

        .set_oncancel = &set_oncancel,
        .set_onclose = &set_onclose,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_destroy = &call_destroy,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestClose = &call_requestClose,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CloseWatcherImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CloseWatcherImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: CloseWatcherOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CloseWatcherImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try CloseWatcherImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CloseWatcherImpl.set_oncancel(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try CloseWatcherImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CloseWatcherImpl.set_onclose(instance, value);
    }

    pub fn call_requestClose(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_requestClose(instance);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try CloseWatcherImpl.call_when(instance, @"type", options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_destroy(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try CloseWatcherImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try CloseWatcherImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try CloseWatcherImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try CloseWatcherImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

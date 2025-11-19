//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MessagePortImpl = @import("impls").MessagePort;
const EventTarget = @import("interfaces").EventTarget;
const MessageEventTarget = @import("interfaces").MessageEventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const MessagePort = struct {
    pub const Meta = struct {
        pub const name = "MessagePort";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "AudioWorklet" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .AudioWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onclose: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MessagePort, .{
        .deinit_fn = &deinit_wrapper,

        .get_onclose = &get_onclose,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onclose = &set_onclose,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_postMessage = &call_postMessage,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MessagePortImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MessagePortImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try MessagePortImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MessagePortImpl.set_onclose(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try MessagePortImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MessagePortImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try MessagePortImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MessagePortImpl.set_onmessageerror(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MessagePortImpl.call_when(instance, @"type", options);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: anyopaque, transfer: anyopaque) anyerror!void {
        
        return try MessagePortImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MessagePortImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try MessagePortImpl.call_start(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try MessagePortImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try MessagePortImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try MessagePortImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

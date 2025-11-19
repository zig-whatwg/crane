//! Generated from: serial.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SerialImpl = @import("impls").Serial;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const SerialPortRequestOptions = @import("dictionaries").SerialPortRequestOptions;
const SerialPort = @import("interfaces").SerialPort;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const Serial = struct {
    pub const Meta = struct {
        pub const name = "Serial";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Serial, .{
        .deinit_fn = &deinit_wrapper,

        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getPorts = &call_getPorts,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestPort = &call_requestPort,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SerialImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SerialImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialImpl.set_ondisconnect(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SerialImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getPorts(instance: *runtime.Instance) anyerror!anyopaque {
        return try SerialImpl.call_getPorts(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPort(instance: *runtime.Instance, options: SerialPortRequestOptions) anyerror!anyopaque {
        
        return try SerialImpl.call_requestPort(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SerialImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try SerialImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try SerialImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

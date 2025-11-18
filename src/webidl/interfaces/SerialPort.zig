//! Generated from: serial.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SerialPortImpl = @import("impls").SerialPort;
const EventTarget = @import("interfaces").EventTarget;
const SerialOutputSignals = @import("dictionaries").SerialOutputSignals;
const ReadableStream = @import("interfaces").ReadableStream;
const SerialPortInfo = @import("dictionaries").SerialPortInfo;
const Promise<SerialInputSignals> = @import("interfaces").Promise<SerialInputSignals>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const WritableStream = @import("interfaces").WritableStream;
const SerialOptions = @import("dictionaries").SerialOptions;
const EventHandler = @import("typedefs").EventHandler;

pub const SerialPort = struct {
    pub const Meta = struct {
        pub const name = "SerialPort";
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
            connected: bool = undefined,
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SerialPort, .{
        .deinit_fn = &deinit_wrapper,

        .get_connected = &get_connected,
        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_forget = &call_forget,
        .call_getInfo = &call_getInfo,
        .call_getSignals = &call_getSignals,
        .call_open = &call_open,
        .call_removeEventListener = &call_removeEventListener,
        .call_setSignals = &call_setSignals,
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
        SerialPortImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SerialPortImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialPortImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialPortImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialPortImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialPortImpl.set_ondisconnect(instance, value);
    }

    pub fn get_connected(instance: *runtime.Instance) anyerror!bool {
        return try SerialPortImpl.get_connected(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try SerialPortImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!WritableStream {
        return try SerialPortImpl.get_writable(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SerialPortImpl.call_when(instance, type_, options);
    }

    pub fn call_open(instance: *runtime.Instance, options: SerialOptions) anyerror!anyopaque {
        
        return try SerialPortImpl.call_open(instance, options);
    }

    pub fn call_setSignals(instance: *runtime.Instance, signals: SerialOutputSignals) anyerror!anyopaque {
        
        return try SerialPortImpl.call_setSignals(instance, signals);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SerialPortImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!anyopaque {
        return try SerialPortImpl.call_forget(instance);
    }

    pub fn call_getInfo(instance: *runtime.Instance) anyerror!SerialPortInfo {
        return try SerialPortImpl.call_getInfo(instance);
    }

    pub fn call_getSignals(instance: *runtime.Instance) anyerror!anyopaque {
        return try SerialPortImpl.call_getSignals(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try SerialPortImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SerialPortImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SerialPortImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

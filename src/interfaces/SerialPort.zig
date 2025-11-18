//! Generated from: serial.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SerialPortImpl = @import("../impls/SerialPort.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        SerialPortImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SerialPortImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.get_onconnect(state);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SerialPortImpl.set_onconnect(state, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.get_ondisconnect(state);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SerialPortImpl.set_ondisconnect(state, value);
    }

    pub fn get_connected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SerialPortImpl.get_connected(state);
    }

    pub fn get_readable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.get_readable(state);
    }

    pub fn get_writable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.get_writable(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialPortImpl.call_when(state, type_, options);
    }

    pub fn call_open(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialPortImpl.call_open(state, options);
    }

    pub fn call_setSignals(instance: *runtime.Instance, signals: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialPortImpl.call_setSignals(state, signals);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SerialPortImpl.call_dispatchEvent(state, event);
    }

    pub fn call_forget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.call_forget(state);
    }

    pub fn call_getInfo(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.call_getInfo(state);
    }

    pub fn call_getSignals(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.call_getSignals(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialPortImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialPortImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialPortImpl.call_removeEventListener(state, type_, callback, options);
    }

};

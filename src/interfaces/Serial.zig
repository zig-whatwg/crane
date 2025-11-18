//! Generated from: serial.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SerialImpl = @import("../impls/Serial.zig");
const EventTarget = @import("EventTarget.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SerialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SerialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialImpl.get_onconnect(state);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SerialImpl.set_onconnect(state, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialImpl.get_ondisconnect(state);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SerialImpl.set_ondisconnect(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SerialImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getPorts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SerialImpl.call_getPorts(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPort(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialImpl.call_requestPort(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SerialImpl.call_removeEventListener(state, type_, callback, options);
    }

};

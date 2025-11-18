//! Generated from: presentation-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationConnectionListImpl = @import("../impls/PresentationConnectionList.zig");
const EventTarget = @import("EventTarget.zig");

pub const PresentationConnectionList = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnectionList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            connections: FrozenArray<PresentationConnection> = undefined,
            onconnectionavailable: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PresentationConnectionList, .{
        .deinit_fn = &deinit_wrapper,

        .get_connections = &get_connections,
        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

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
        PresentationConnectionListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PresentationConnectionListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_connections(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionListImpl.get_connections(state);
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionListImpl.get_onconnectionavailable(state);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationConnectionListImpl.set_onconnectionavailable(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PresentationConnectionListImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationConnectionListImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationConnectionListImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationConnectionListImpl.call_removeEventListener(state, type_, callback, options);
    }

};

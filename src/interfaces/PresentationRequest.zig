//! Generated from: presentation-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationRequestImpl = @import("../impls/PresentationRequest.zig");
const EventTarget = @import("EventTarget.zig");

pub const PresentationRequest = struct {
    pub const Meta = struct {
        pub const name = "PresentationRequest";
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
            onconnectionavailable: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PresentationRequest, .{
        .deinit_fn = &deinit_wrapper,

        .get_onconnectionavailable = &get_onconnectionavailable,

        .set_onconnectionavailable = &set_onconnectionavailable,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAvailability = &call_getAvailability,
        .call_reconnect = &call_reconnect,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
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
        PresentationRequestImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PresentationRequestImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PresentationRequestImpl.constructor(state, url);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, urls: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PresentationRequestImpl.constructor(state, urls);
        
        return instance;
    }

    pub fn get_onconnectionavailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationRequestImpl.get_onconnectionavailable(state);
    }

    pub fn set_onconnectionavailable(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationRequestImpl.set_onconnectionavailable(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationRequestImpl.call_when(state, type_, options);
    }

    pub fn call_reconnect(instance: *runtime.Instance, presentationId: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return PresentationRequestImpl.call_reconnect(state, presentationId);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationRequestImpl.call_getAvailability(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PresentationRequestImpl.call_dispatchEvent(state, event);
    }

    pub fn call_start(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationRequestImpl.call_start(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationRequestImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationRequestImpl.call_removeEventListener(state, type_, callback, options);
    }

};

//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRSystemImpl = @import("../impls/XRSystem.zig");
const EventTarget = @import("EventTarget.zig");

pub const XRSystem = struct {
    pub const Meta = struct {
        pub const name = "XRSystem";
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
            ondevicechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRSystem, .{
        .deinit_fn = &deinit_wrapper,

        .get_ondevicechange = &get_ondevicechange,

        .set_ondevicechange = &set_ondevicechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_isSessionSupported = &call_isSessionSupported,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestSession = &call_requestSession,
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
        XRSystemImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRSystemImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ondevicechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRSystemImpl.get_ondevicechange(state);
    }

    pub fn set_ondevicechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRSystemImpl.set_ondevicechange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRSystemImpl.call_dispatchEvent(state, event);
    }

    pub fn call_isSessionSupported(instance: *runtime.Instance, mode: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSystemImpl.call_isSessionSupported(state, mode);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSystemImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestSession(instance: *runtime.Instance, mode: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return XRSystemImpl.call_requestSession(state, mode, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSystemImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRSystemImpl.call_removeEventListener(state, type_, callback, options);
    }

};

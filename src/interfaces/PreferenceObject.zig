//! Generated from: mediaqueries-5.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PreferenceObjectImpl = @import("../impls/PreferenceObject.zig");
const EventTarget = @import("EventTarget.zig");

pub const PreferenceObject = struct {
    pub const Meta = struct {
        pub const name = "PreferenceObject";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            override: ?runtime.DOMString = null,
            value: runtime.DOMString = undefined,
            validValues: FrozenArray<DOMString> = undefined,
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PreferenceObject, .{
        .deinit_fn = &deinit_wrapper,

        .get_onchange = &get_onchange,
        .get_override = &get_override,
        .get_validValues = &get_validValues,
        .get_value = &get_value,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_clearOverride = &call_clearOverride,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestOverride = &call_requestOverride,
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
        PreferenceObjectImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PreferenceObjectImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_override(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceObjectImpl.get_override(state);
    }

    pub fn get_value(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PreferenceObjectImpl.get_value(state);
    }

    pub fn get_validValues(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceObjectImpl.get_validValues(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceObjectImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PreferenceObjectImpl.set_onchange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PreferenceObjectImpl.call_dispatchEvent(state, event);
    }

    pub fn call_requestOverride(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PreferenceObjectImpl.call_requestOverride(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PreferenceObjectImpl.call_when(state, type_, options);
    }

    pub fn call_clearOverride(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceObjectImpl.call_clearOverride(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PreferenceObjectImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PreferenceObjectImpl.call_removeEventListener(state, type_, callback, options);
    }

};

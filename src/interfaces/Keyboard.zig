//! Generated from: keyboard-lock.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyboardImpl = @import("../impls/Keyboard.zig");
const EventTarget = @import("EventTarget.zig");

pub const Keyboard = struct {
    pub const Meta = struct {
        pub const name = "Keyboard";
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
            onlayoutchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Keyboard, .{
        .deinit_fn = &deinit_wrapper,

        .get_onlayoutchange = &get_onlayoutchange,

        .set_onlayoutchange = &set_onlayoutchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getLayoutMap = &call_getLayoutMap,
        .call_lock = &call_lock,
        .call_removeEventListener = &call_removeEventListener,
        .call_unlock = &call_unlock,
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
        KeyboardImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        KeyboardImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onlayoutchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardImpl.get_onlayoutchange(state);
    }

    pub fn set_onlayoutchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        KeyboardImpl.set_onlayoutchange(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardImpl.call_when(state, type_, options);
    }

    pub fn call_lock(instance: *runtime.Instance, keyCodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardImpl.call_lock(state, keyCodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return KeyboardImpl.call_dispatchEvent(state, event);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardImpl.call_unlock(state);
    }

    pub fn call_getLayoutMap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return KeyboardImpl.call_getLayoutMap(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return KeyboardImpl.call_removeEventListener(state, type_, callback, options);
    }

};

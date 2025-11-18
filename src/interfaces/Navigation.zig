//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationImpl = @import("../impls/Navigation.zig");
const EventTarget = @import("EventTarget.zig");

pub const Navigation = struct {
    pub const Meta = struct {
        pub const name = "Navigation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            currentEntry: ?NavigationHistoryEntry = null,
            transition: ?NavigationTransition = null,
            activation: ?NavigationActivation = null,
            canGoBack: bool = undefined,
            canGoForward: bool = undefined,
            onnavigate: EventHandler = undefined,
            onnavigatesuccess: EventHandler = undefined,
            onnavigateerror: EventHandler = undefined,
            oncurrententrychange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Navigation, .{
        .deinit_fn = &deinit_wrapper,

        .get_activation = &get_activation,
        .get_canGoBack = &get_canGoBack,
        .get_canGoForward = &get_canGoForward,
        .get_currentEntry = &get_currentEntry,
        .get_oncurrententrychange = &get_oncurrententrychange,
        .get_onnavigate = &get_onnavigate,
        .get_onnavigateerror = &get_onnavigateerror,
        .get_onnavigatesuccess = &get_onnavigatesuccess,
        .get_transition = &get_transition,

        .set_oncurrententrychange = &set_oncurrententrychange,
        .set_onnavigate = &set_onnavigate,
        .set_onnavigateerror = &set_onnavigateerror,
        .set_onnavigatesuccess = &set_onnavigatesuccess,

        .call_addEventListener = &call_addEventListener,
        .call_back = &call_back,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_entries = &call_entries,
        .call_forward = &call_forward,
        .call_navigate = &call_navigate,
        .call_reload = &call_reload,
        .call_removeEventListener = &call_removeEventListener,
        .call_traverseTo = &call_traverseTo,
        .call_updateCurrentEntry = &call_updateCurrentEntry,
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
        NavigationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_currentEntry(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_currentEntry(state);
    }

    pub fn get_transition(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_transition(state);
    }

    pub fn get_activation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_activation(state);
    }

    pub fn get_canGoBack(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigationImpl.get_canGoBack(state);
    }

    pub fn get_canGoForward(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigationImpl.get_canGoForward(state);
    }

    pub fn get_onnavigate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_onnavigate(state);
    }

    pub fn set_onnavigate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NavigationImpl.set_onnavigate(state, value);
    }

    pub fn get_onnavigatesuccess(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_onnavigatesuccess(state);
    }

    pub fn set_onnavigatesuccess(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NavigationImpl.set_onnavigatesuccess(state, value);
    }

    pub fn get_onnavigateerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_onnavigateerror(state);
    }

    pub fn set_onnavigateerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NavigationImpl.set_onnavigateerror(state, value);
    }

    pub fn get_oncurrententrychange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.get_oncurrententrychange(state);
    }

    pub fn set_oncurrententrychange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NavigationImpl.set_oncurrententrychange(state, value);
    }

    pub fn call_reload(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_reload(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_when(state, type_, options);
    }

    pub fn call_back(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_back(state, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NavigationImpl.call_dispatchEvent(state, event);
    }

    pub fn call_entries(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationImpl.call_entries(state);
    }

    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_navigate(state, url, options);
    }

    pub fn call_traverseTo(instance: *runtime.Instance, key: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_traverseTo(state, key, options);
    }

    pub fn call_forward(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_forward(state, options);
    }

    pub fn call_updateCurrentEntry(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_updateCurrentEntry(state, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigationImpl.call_removeEventListener(state, type_, callback, options);
    }

};

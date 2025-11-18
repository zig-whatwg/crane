//! Generated from: window-management.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenDetailsImpl = @import("../impls/ScreenDetails.zig");
const EventTarget = @import("EventTarget.zig");

pub const ScreenDetails = struct {
    pub const Meta = struct {
        pub const name = "ScreenDetails";
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
            screens: FrozenArray<ScreenDetailed> = undefined,
            currentScreen: ScreenDetailed = undefined,
            onscreenschange: EventHandler = undefined,
            oncurrentscreenchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ScreenDetails, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentScreen = &get_currentScreen,
        .get_oncurrentscreenchange = &get_oncurrentscreenchange,
        .get_onscreenschange = &get_onscreenschange,
        .get_screens = &get_screens,

        .set_oncurrentscreenchange = &set_oncurrentscreenchange,
        .set_onscreenschange = &set_onscreenschange,

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
        ScreenDetailsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ScreenDetailsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_screens(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenDetailsImpl.get_screens(state);
    }

    pub fn get_currentScreen(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenDetailsImpl.get_currentScreen(state);
    }

    pub fn get_onscreenschange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenDetailsImpl.get_onscreenschange(state);
    }

    pub fn set_onscreenschange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ScreenDetailsImpl.set_onscreenschange(state, value);
    }

    pub fn get_oncurrentscreenchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScreenDetailsImpl.get_oncurrentscreenchange(state);
    }

    pub fn set_oncurrentscreenchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ScreenDetailsImpl.set_oncurrentscreenchange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ScreenDetailsImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenDetailsImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenDetailsImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ScreenDetailsImpl.call_removeEventListener(state, type_, callback, options);
    }

};

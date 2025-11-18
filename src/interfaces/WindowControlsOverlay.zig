//! Generated from: window-controls-overlay.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowControlsOverlayImpl = @import("../impls/WindowControlsOverlay.zig");
const EventTarget = @import("EventTarget.zig");

pub const WindowControlsOverlay = struct {
    pub const Meta = struct {
        pub const name = "WindowControlsOverlay";
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
            visible: bool = undefined,
            ongeometrychange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WindowControlsOverlay, .{
        .deinit_fn = &deinit_wrapper,

        .get_ongeometrychange = &get_ongeometrychange,
        .get_visible = &get_visible,

        .set_ongeometrychange = &set_ongeometrychange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getTitlebarAreaRect = &call_getTitlebarAreaRect,
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
        WindowControlsOverlayImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WindowControlsOverlayImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_visible(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return WindowControlsOverlayImpl.get_visible(state);
    }

    pub fn get_ongeometrychange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowControlsOverlayImpl.get_ongeometrychange(state);
    }

    pub fn set_ongeometrychange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WindowControlsOverlayImpl.set_ongeometrychange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return WindowControlsOverlayImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowControlsOverlayImpl.call_when(state, type_, options);
    }

    pub fn call_getTitlebarAreaRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WindowControlsOverlayImpl.call_getTitlebarAreaRect(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowControlsOverlayImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WindowControlsOverlayImpl.call_removeEventListener(state, type_, callback, options);
    }

};

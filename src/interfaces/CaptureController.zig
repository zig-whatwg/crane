//! Generated from: screen-capture.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CaptureControllerImpl = @import("../impls/CaptureController.zig");
const EventTarget = @import("EventTarget.zig");

pub const CaptureController = struct {
    pub const Meta = struct {
        pub const name = "CaptureController";
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
            zoomLevel: ?i32 = null,
            onzoomlevelchange: EventHandler = undefined,
            oncapturedmousechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CaptureController, .{
        .deinit_fn = &deinit_wrapper,

        .get_oncapturedmousechange = &get_oncapturedmousechange,
        .get_onzoomlevelchange = &get_onzoomlevelchange,
        .get_zoomLevel = &get_zoomLevel,

        .set_oncapturedmousechange = &set_oncapturedmousechange,
        .set_onzoomlevelchange = &set_onzoomlevelchange,

        .call_addEventListener = &call_addEventListener,
        .call_decreaseZoomLevel = &call_decreaseZoomLevel,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_forwardWheel = &call_forwardWheel,
        .call_getSupportedZoomLevels = &call_getSupportedZoomLevels,
        .call_increaseZoomLevel = &call_increaseZoomLevel,
        .call_removeEventListener = &call_removeEventListener,
        .call_resetZoomLevel = &call_resetZoomLevel,
        .call_setFocusBehavior = &call_setFocusBehavior,
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
        CaptureControllerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CaptureControllerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CaptureControllerImpl.constructor(state);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CaptureControllerImpl.constructor(state);
        
        return instance;
    }

    pub fn get_zoomLevel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.get_zoomLevel(state);
    }

    pub fn get_onzoomlevelchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.get_onzoomlevelchange(state);
    }

    pub fn set_onzoomlevelchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CaptureControllerImpl.set_onzoomlevelchange(state, value);
    }

    pub fn get_oncapturedmousechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.get_oncapturedmousechange(state);
    }

    pub fn set_oncapturedmousechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CaptureControllerImpl.set_oncapturedmousechange(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CaptureControllerImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_resetZoomLevel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.call_resetZoomLevel(state);
    }

    pub fn call_setFocusBehavior(instance: *runtime.Instance, focusBehavior: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CaptureControllerImpl.call_setFocusBehavior(state, focusBehavior);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CaptureControllerImpl.call_when(state, type_, options);
    }

    pub fn call_decreaseZoomLevel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.call_decreaseZoomLevel(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return CaptureControllerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_increaseZoomLevel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.call_increaseZoomLevel(state);
    }

    pub fn call_forwardWheel(instance: *runtime.Instance, element: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CaptureControllerImpl.call_forwardWheel(state, element);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CaptureControllerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_getSupportedZoomLevels(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CaptureControllerImpl.call_getSupportedZoomLevels(state);
    }

};

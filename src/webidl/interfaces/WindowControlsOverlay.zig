//! Generated from: window-controls-overlay.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowControlsOverlayImpl = @import("impls").WindowControlsOverlay;
const EventTarget = @import("interfaces").EventTarget;
const DOMRect = @import("interfaces").DOMRect;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        WindowControlsOverlayImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowControlsOverlayImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_visible(instance: *runtime.Instance) anyerror!bool {
        return try WindowControlsOverlayImpl.get_visible(instance);
    }

    pub fn get_ongeometrychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try WindowControlsOverlayImpl.get_ongeometrychange(instance);
    }

    pub fn set_ongeometrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WindowControlsOverlayImpl.set_ongeometrychange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try WindowControlsOverlayImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try WindowControlsOverlayImpl.call_when(instance, type_, options);
    }

    pub fn call_getTitlebarAreaRect(instance: *runtime.Instance) anyerror!DOMRect {
        return try WindowControlsOverlayImpl.call_getTitlebarAreaRect(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try WindowControlsOverlayImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try WindowControlsOverlayImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

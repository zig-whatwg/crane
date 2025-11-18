//! Generated from: cssom-view.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VisualViewportImpl = @import("../impls/VisualViewport.zig");
const EventTarget = @import("EventTarget.zig");

pub const VisualViewport = struct {
    pub const Meta = struct {
        pub const name = "VisualViewport";
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
            offsetLeft: f64 = undefined,
            offsetTop: f64 = undefined,
            pageLeft: f64 = undefined,
            pageTop: f64 = undefined,
            width: f64 = undefined,
            height: f64 = undefined,
            scale: f64 = undefined,
            onresize: EventHandler = undefined,
            onscroll: EventHandler = undefined,
            onscrollend: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VisualViewport, .{
        .deinit_fn = &deinit_wrapper,

        .get_height = &get_height,
        .get_offsetLeft = &get_offsetLeft,
        .get_offsetTop = &get_offsetTop,
        .get_onresize = &get_onresize,
        .get_onscroll = &get_onscroll,
        .get_onscrollend = &get_onscrollend,
        .get_pageLeft = &get_pageLeft,
        .get_pageTop = &get_pageTop,
        .get_scale = &get_scale,
        .get_width = &get_width,

        .set_onresize = &set_onresize,
        .set_onscroll = &set_onscroll,
        .set_onscrollend = &set_onscrollend,

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
        VisualViewportImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VisualViewportImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_offsetLeft(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_offsetLeft(state);
    }

    pub fn get_offsetTop(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_offsetTop(state);
    }

    pub fn get_pageLeft(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_pageLeft(state);
    }

    pub fn get_pageTop(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_pageTop(state);
    }

    pub fn get_width(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_height(state);
    }

    pub fn get_scale(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VisualViewportImpl.get_scale(state);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VisualViewportImpl.get_onresize(state);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VisualViewportImpl.set_onresize(state, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VisualViewportImpl.get_onscroll(state);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VisualViewportImpl.set_onscroll(state, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VisualViewportImpl.get_onscrollend(state);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VisualViewportImpl.set_onscrollend(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return VisualViewportImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VisualViewportImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VisualViewportImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VisualViewportImpl.call_removeEventListener(state, type_, callback, options);
    }

};

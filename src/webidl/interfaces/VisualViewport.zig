//! Generated from: cssom-view.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VisualViewportImpl = @import("impls").VisualViewport;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        VisualViewportImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VisualViewportImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_offsetLeft(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_offsetLeft(instance);
    }

    pub fn get_offsetTop(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_offsetTop(instance);
    }

    pub fn get_pageLeft(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_pageLeft(instance);
    }

    pub fn get_pageTop(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_pageTop(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_height(instance);
    }

    pub fn get_scale(instance: *runtime.Instance) anyerror!f64 {
        return try VisualViewportImpl.get_scale(instance);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyerror!EventHandler {
        return try VisualViewportImpl.get_onresize(instance);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VisualViewportImpl.set_onresize(instance, value);
    }

    pub fn get_onscroll(instance: *runtime.Instance) anyerror!EventHandler {
        return try VisualViewportImpl.get_onscroll(instance);
    }

    pub fn set_onscroll(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VisualViewportImpl.set_onscroll(instance, value);
    }

    pub fn get_onscrollend(instance: *runtime.Instance) anyerror!EventHandler {
        return try VisualViewportImpl.get_onscrollend(instance);
    }

    pub fn set_onscrollend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VisualViewportImpl.set_onscrollend(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try VisualViewportImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try VisualViewportImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try VisualViewportImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try VisualViewportImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

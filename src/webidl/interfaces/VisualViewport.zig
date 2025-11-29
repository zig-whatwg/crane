//! Generated from: cssom-view.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VisualViewportImpl = @import("impls").VisualViewport;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const VisualViewport = struct {
    pub const Meta = struct {
        pub const name = "VisualViewport";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "offsetLeft", "get_offsetLeft", null },
            .{ "offsetTop", "get_offsetTop", null },
            .{ "pageLeft", "get_pageLeft", null },
            .{ "pageTop", "get_pageTop", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "scale", "get_scale", null },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "pageLeft", "get_pageLeft", null },
            .{ "pageTop", "get_pageTop", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "scale", "get_scale", null },
            .{ "onresize", "get_onresize", "set_onresize" },
            .{ "onscroll", "get_onscroll", "set_onscroll" },
            .{ "onscrollend", "get_onscrollend", "set_onscrollend" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "offsetLeft", "get_offsetLeft", null },
            .{ "offsetTop", "get_offsetTop", null },
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            _internal: ?*VisualViewportImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VisualViewportImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VisualViewportImpl.deinit(instance);
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

};

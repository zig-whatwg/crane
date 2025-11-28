//! Generated from: window-controls-overlay.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WindowControlsOverlayImpl = @import("impls").WindowControlsOverlay;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMRect = @import("interfaces").DOMRect;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const WindowControlsOverlay = struct {
    pub const Meta = struct {
        pub const name = "WindowControlsOverlay";
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
            .{ "visible", "get_visible", null },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTitlebarAreaRect", "call_getTitlebarAreaRect", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTitlebarAreaRect",
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
            .{ "visible", "get_visible", null },
            .{ "ongeometrychange", "get_ongeometrychange", "set_ongeometrychange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            visible: bool = undefined,
            ongeometrychange: EventHandler = undefined,
            _internal: ?*WindowControlsOverlayImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_ongeometrychange = &get_ongeometrychange,
        .get_visible = &get_visible,

        .set_ongeometrychange = &set_ongeometrychange,

        .call_getTitlebarAreaRect = &call_getTitlebarAreaRect,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowControlsOverlayImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowControlsOverlayImpl.deinit(instance);
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

    pub fn call_getTitlebarAreaRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WindowControlsOverlayImpl.call_getTitlebarAreaRect(instance);
    }

};

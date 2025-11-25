//! Generated from: screen-capture.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CaptureControllerImpl = @import("impls").CaptureController;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const CaptureStartFocusBehavior = @import("enums").CaptureStartFocusBehavior;
const Event = @import("interfaces").Event;
const HTMLElement = @import("interfaces").HTMLElement;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const CaptureController = struct {
    pub const Meta = struct {
        pub const name = "CaptureController";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "zoomLevel", "get_zoomLevel", null },
            .{ "onzoomlevelchange", "get_onzoomlevelchange", "set_onzoomlevelchange" },
            .{ "oncapturedmousechange", "get_oncapturedmousechange", "set_oncapturedmousechange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setFocusBehavior", "call_setFocusBehavior", 1 },
            .{ "getSupportedZoomLevels", "call_getSupportedZoomLevels", 0 },
            .{ "increaseZoomLevel", "call_increaseZoomLevel", 0 },
            .{ "decreaseZoomLevel", "call_decreaseZoomLevel", 0 },
            .{ "resetZoomLevel", "call_resetZoomLevel", 0 },
            .{ "forwardWheel", "call_forwardWheel", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setFocusBehavior",
            "getSupportedZoomLevels",
            "increaseZoomLevel",
            "decreaseZoomLevel",
            "resetZoomLevel",
            "forwardWheel",
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
            .{ "zoomLevel", "get_zoomLevel", null },
            .{ "onzoomlevelchange", "get_onzoomlevelchange", "set_onzoomlevelchange" },
            .{ "oncapturedmousechange", "get_oncapturedmousechange", "set_oncapturedmousechange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            zoomLevel: ?i32 = null,
            onzoomlevelchange: EventHandler = undefined,
            oncapturedmousechange: EventHandler = undefined,
            _internal: ?*CaptureControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_oncapturedmousechange = &get_oncapturedmousechange,
        .get_onzoomlevelchange = &get_onzoomlevelchange,
        .get_zoomLevel = &get_zoomLevel,

        .set_oncapturedmousechange = &set_oncapturedmousechange,
        .set_onzoomlevelchange = &set_onzoomlevelchange,

        .call_decreaseZoomLevel = &call_decreaseZoomLevel,
        .call_forwardWheel = &call_forwardWheel,
        .call_getSupportedZoomLevels = &call_getSupportedZoomLevels,
        .call_increaseZoomLevel = &call_increaseZoomLevel,
        .call_resetZoomLevel = &call_resetZoomLevel,
        .call_setFocusBehavior = &call_setFocusBehavior,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CaptureControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CaptureControllerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CaptureControllerImpl.call_constructor(allocator, ctx);
    }

    pub fn get_zoomLevel(instance: *runtime.Instance) anyerror!?i32 {
        return try CaptureControllerImpl.get_zoomLevel(instance);
    }

    pub fn get_onzoomlevelchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try CaptureControllerImpl.get_onzoomlevelchange(instance);
    }

    pub fn set_onzoomlevelchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CaptureControllerImpl.set_onzoomlevelchange(instance, value);
    }

    pub fn get_oncapturedmousechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try CaptureControllerImpl.get_oncapturedmousechange(instance);
    }

    pub fn set_oncapturedmousechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CaptureControllerImpl.set_oncapturedmousechange(instance, value);
    }

    pub fn call_increaseZoomLevel(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CaptureControllerImpl.call_increaseZoomLevel(instance);
    }

    pub fn call_forwardWheel(instance: *runtime.Instance, element: *runtime.Instance) anyerror!*const anyopaque {
        
        return try CaptureControllerImpl.call_forwardWheel(instance, element);
    }

    pub fn call_setFocusBehavior(instance: *runtime.Instance, focusBehavior: CaptureStartFocusBehavior) anyerror!void {
        
        return try CaptureControllerImpl.call_setFocusBehavior(instance, focusBehavior);
    }

    pub fn call_decreaseZoomLevel(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CaptureControllerImpl.call_decreaseZoomLevel(instance);
    }

    pub fn call_resetZoomLevel(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CaptureControllerImpl.call_resetZoomLevel(instance);
    }

    pub fn call_getSupportedZoomLevels(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CaptureControllerImpl.call_getSupportedZoomLevels(instance);
    }

};

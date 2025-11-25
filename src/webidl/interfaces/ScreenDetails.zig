//! Generated from: window-management.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenDetailsImpl = @import("impls").ScreenDetails;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const ScreenDetailed = @import("interfaces").ScreenDetailed;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const ScreenDetails = struct {
    pub const Meta = struct {
        pub const name = "ScreenDetails";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "screens", "get_screens", null },
            .{ "currentScreen", "get_currentScreen", null },
            .{ "onscreenschange", "get_onscreenschange", "set_onscreenschange" },
            .{ "oncurrentscreenchange", "get_oncurrentscreenchange", "set_oncurrentscreenchange" },
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
            .{ "screens", "get_screens", null },
            .{ "currentScreen", "get_currentScreen", null },
            .{ "onscreenschange", "get_onscreenschange", "set_onscreenschange" },
            .{ "oncurrentscreenchange", "get_oncurrentscreenchange", "set_oncurrentscreenchange" },
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
            screens: runtime.FrozenArray(ScreenDetailed) = undefined,
            currentScreen: *runtime.Instance = undefined,
            onscreenschange: EventHandler = undefined,
            oncurrentscreenchange: EventHandler = undefined,
            _internal: ?*ScreenDetailsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentScreen = &get_currentScreen,
        .get_oncurrentscreenchange = &get_oncurrentscreenchange,
        .get_onscreenschange = &get_onscreenschange,
        .get_screens = &get_screens,

        .set_oncurrentscreenchange = &set_oncurrentscreenchange,
        .set_onscreenschange = &set_onscreenschange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScreenDetailsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenDetailsImpl.deinit(instance);
    }

    pub fn get_screens(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ScreenDetailsImpl.get_screens(instance);
    }

    pub fn get_currentScreen(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ScreenDetailsImpl.get_currentScreen(instance);
    }

    pub fn get_onscreenschange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenDetailsImpl.get_onscreenschange(instance);
    }

    pub fn set_onscreenschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenDetailsImpl.set_onscreenschange(instance, value);
    }

    pub fn get_oncurrentscreenchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenDetailsImpl.get_oncurrentscreenchange(instance);
    }

    pub fn set_oncurrentscreenchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenDetailsImpl.set_oncurrentscreenchange(instance, value);
    }

};

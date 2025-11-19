//! Generated from: window-management.idl
//! Generated at: 2025-11-19T20:02:01Z
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
            screens: runtime.FrozenArray(ScreenDetailed) = undefined,
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
        return ScreenDetailsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenDetailsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_screens(instance: *runtime.Instance) anyerror!anyopaque {
        return try ScreenDetailsImpl.get_screens(instance);
    }

    pub fn get_currentScreen(instance: *runtime.Instance) anyerror!ScreenDetailed {
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

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ScreenDetailsImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ScreenDetailsImpl.call_when(instance, @"type", options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try ScreenDetailsImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try ScreenDetailsImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

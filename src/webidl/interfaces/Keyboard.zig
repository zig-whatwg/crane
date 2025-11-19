//! Generated from: keyboard-lock.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const KeyboardImpl = @import("impls").Keyboard;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const KeyboardLayoutMap = @import("interfaces").KeyboardLayoutMap;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const Keyboard = struct {
    pub const Meta = struct {
        pub const name = "Keyboard";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onlayoutchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Keyboard, .{
        .deinit_fn = &deinit_wrapper,

        .get_onlayoutchange = &get_onlayoutchange,

        .set_onlayoutchange = &set_onlayoutchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getLayoutMap = &call_getLayoutMap,
        .call_lock = &call_lock,
        .call_removeEventListener = &call_removeEventListener,
        .call_unlock = &call_unlock,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return KeyboardImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        KeyboardImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onlayoutchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try KeyboardImpl.get_onlayoutchange(instance);
    }

    pub fn set_onlayoutchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try KeyboardImpl.set_onlayoutchange(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try KeyboardImpl.call_when(instance, @"type", options);
    }

    pub fn call_lock(instance: *runtime.Instance, keyCodes: anyopaque) anyerror!anyopaque {
        
        return try KeyboardImpl.call_lock(instance, keyCodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try KeyboardImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
        return try KeyboardImpl.call_unlock(instance);
    }

    pub fn call_getLayoutMap(instance: *runtime.Instance) anyerror!anyopaque {
        return try KeyboardImpl.call_getLayoutMap(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try KeyboardImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try KeyboardImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

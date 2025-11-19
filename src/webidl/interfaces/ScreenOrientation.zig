//! Generated from: screen-orientation.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenOrientationImpl = @import("impls").ScreenOrientation;
const EventTarget = @import("interfaces").EventTarget;
const OrientationType = @import("enums").OrientationType;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const OrientationLockType = @import("enums").OrientationLockType;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const ScreenOrientation = struct {
    pub const Meta = struct {
        pub const name = "ScreenOrientation";
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
            @"type": OrientationType = undefined,
            angle: u16 = undefined,
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ScreenOrientation, .{
        .deinit_fn = &deinit_wrapper,

        .get_angle = &get_angle,
        .get_onchange = &get_onchange,
        .get_type = &get_type,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_lock = &call_lock,
        .call_removeEventListener = &call_removeEventListener,
        .call_unlock = &call_unlock,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ScreenOrientationImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenOrientationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!OrientationType {
        return try ScreenOrientationImpl.get_type(instance);
    }

    pub fn get_angle(instance: *runtime.Instance) anyerror!u16 {
        return try ScreenOrientationImpl.get_angle(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenOrientationImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenOrientationImpl.set_onchange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ScreenOrientationImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ScreenOrientationImpl.call_when(instance, @"type", options);
    }

    pub fn call_lock(instance: *runtime.Instance, orientation: OrientationLockType) anyerror!anyopaque {
        
        return try ScreenOrientationImpl.call_lock(instance, orientation);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
        return try ScreenOrientationImpl.call_unlock(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try ScreenOrientationImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try ScreenOrientationImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};

//! Generated from: window-management.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScreenDetailsImpl = @import("impls").ScreenDetails;
const EventTarget = @import("interfaces").EventTarget;
const ScreenDetailed = @import("interfaces").ScreenDetailed;
const FrozenArray<ScreenDetailed> = @import("interfaces").FrozenArray<ScreenDetailed>;
const EventHandler = @import("typedefs").EventHandler;

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
            screens: FrozenArray<ScreenDetailed> = undefined,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ScreenDetailsImpl.init(instance);
        
        return instance;
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

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ScreenDetailsImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ScreenDetailsImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ScreenDetailsImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

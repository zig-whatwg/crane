//! Generated from: screen-capture.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CaptureControllerImpl = @import("impls").CaptureController;
const EventTarget = @import("interfaces").EventTarget;
const CaptureStartFocusBehavior = @import("enums").CaptureStartFocusBehavior;
const HTMLElement = @import("interfaces").HTMLElement;
const long = @import("interfaces").long;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const CaptureController = struct {
    pub const Meta = struct {
        pub const name = "CaptureController";
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
            zoomLevel: ?i32 = null,
            onzoomlevelchange: EventHandler = undefined,
            oncapturedmousechange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CaptureController, .{
        .deinit_fn = &deinit_wrapper,

        .get_oncapturedmousechange = &get_oncapturedmousechange,
        .get_onzoomlevelchange = &get_onzoomlevelchange,
        .get_zoomLevel = &get_zoomLevel,

        .set_oncapturedmousechange = &set_oncapturedmousechange,
        .set_onzoomlevelchange = &set_onzoomlevelchange,

        .call_addEventListener = &call_addEventListener,
        .call_decreaseZoomLevel = &call_decreaseZoomLevel,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_forwardWheel = &call_forwardWheel,
        .call_getSupportedZoomLevels = &call_getSupportedZoomLevels,
        .call_increaseZoomLevel = &call_increaseZoomLevel,
        .call_removeEventListener = &call_removeEventListener,
        .call_resetZoomLevel = &call_resetZoomLevel,
        .call_setFocusBehavior = &call_setFocusBehavior,
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
        CaptureControllerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CaptureControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CaptureControllerImpl.constructor(instance);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CaptureControllerImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_zoomLevel(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CaptureControllerImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_resetZoomLevel(instance: *runtime.Instance) anyerror!anyopaque {
        return try CaptureControllerImpl.call_resetZoomLevel(instance);
    }

    pub fn call_setFocusBehavior(instance: *runtime.Instance, focusBehavior: CaptureStartFocusBehavior) anyerror!void {
        
        return try CaptureControllerImpl.call_setFocusBehavior(instance, focusBehavior);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try CaptureControllerImpl.call_when(instance, type_, options);
    }

    pub fn call_decreaseZoomLevel(instance: *runtime.Instance) anyerror!anyopaque {
        return try CaptureControllerImpl.call_decreaseZoomLevel(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try CaptureControllerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_increaseZoomLevel(instance: *runtime.Instance) anyerror!anyopaque {
        return try CaptureControllerImpl.call_increaseZoomLevel(instance);
    }

    pub fn call_forwardWheel(instance: *runtime.Instance, element: anyopaque) anyerror!anyopaque {
        
        return try CaptureControllerImpl.call_forwardWheel(instance, element);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CaptureControllerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_getSupportedZoomLevels(instance: *runtime.Instance) anyerror!anyopaque {
        return try CaptureControllerImpl.call_getSupportedZoomLevels(instance);
    }

};

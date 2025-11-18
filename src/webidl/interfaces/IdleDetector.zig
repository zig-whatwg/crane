//! Generated from: idle-detection.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdleDetectorImpl = @import("impls").IdleDetector;
const EventTarget = @import("interfaces").EventTarget;
const IdleOptions = @import("dictionaries").IdleOptions;
const ScreenIdleState = @import("enums").ScreenIdleState;
const Promise<PermissionState> = @import("interfaces").Promise<PermissionState>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;
const UserIdleState = @import("enums").UserIdleState;

pub const IdleDetector = struct {
    pub const Meta = struct {
        pub const name = "IdleDetector";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            userState: ?UserIdleState = null,
            screenState: ?ScreenIdleState = null,
            onchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IdleDetector, .{
        .deinit_fn = &deinit_wrapper,

        .get_onchange = &get_onchange,
        .get_screenState = &get_screenState,
        .get_userState = &get_userState,

        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestPermission = &call_requestPermission,
        .call_start = &call_start,
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
        IdleDetectorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdleDetectorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try IdleDetectorImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_userState(instance: *runtime.Instance) anyerror!anyopaque {
        return try IdleDetectorImpl.get_userState(instance);
    }

    pub fn get_screenState(instance: *runtime.Instance) anyerror!anyopaque {
        return try IdleDetectorImpl.get_screenState(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try IdleDetectorImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IdleDetectorImpl.set_onchange(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try IdleDetectorImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPermission(instance: *runtime.Instance) anyerror!anyopaque {
        return try IdleDetectorImpl.call_requestPermission(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try IdleDetectorImpl.call_when(instance, type_, options);
    }

    pub fn call_start(instance: *runtime.Instance, options: IdleOptions) anyerror!anyopaque {
        
        return try IdleDetectorImpl.call_start(instance, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try IdleDetectorImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try IdleDetectorImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

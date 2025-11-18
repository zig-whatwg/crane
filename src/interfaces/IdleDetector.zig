//! Generated from: idle-detection.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdleDetectorImpl = @import("../impls/IdleDetector.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        IdleDetectorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IdleDetectorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try IdleDetectorImpl.constructor(state);
        
        return instance;
    }

    pub fn get_userState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdleDetectorImpl.get_userState(state);
    }

    pub fn get_screenState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdleDetectorImpl.get_screenState(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdleDetectorImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        IdleDetectorImpl.set_onchange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return IdleDetectorImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPermission(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IdleDetectorImpl.call_requestPermission(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IdleDetectorImpl.call_when(state, type_, options);
    }

    pub fn call_start(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IdleDetectorImpl.call_start(state, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IdleDetectorImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IdleDetectorImpl.call_removeEventListener(state, type_, callback, options);
    }

};

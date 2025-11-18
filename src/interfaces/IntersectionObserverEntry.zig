//! Generated from: intersection-observer.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntersectionObserverEntryImpl = @import("../impls/IntersectionObserverEntry.zig");

pub const IntersectionObserverEntry = struct {
    pub const Meta = struct {
        pub const name = "IntersectionObserverEntry";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            time: DOMHighResTimeStamp = undefined,
            rootBounds: ?DOMRectReadOnly = null,
            boundingClientRect: DOMRectReadOnly = undefined,
            intersectionRect: DOMRectReadOnly = undefined,
            isIntersecting: bool = undefined,
            isVisible: bool = undefined,
            intersectionRatio: f64 = undefined,
            target: Element = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IntersectionObserverEntry, .{
        .deinit_fn = &deinit_wrapper,

        .get_boundingClientRect = &get_boundingClientRect,
        .get_intersectionRatio = &get_intersectionRatio,
        .get_intersectionRect = &get_intersectionRect,
        .get_isIntersecting = &get_isIntersecting,
        .get_isVisible = &get_isVisible,
        .get_rootBounds = &get_rootBounds,
        .get_target = &get_target,
        .get_time = &get_time,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IntersectionObserverEntryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IntersectionObserverEntryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, intersectionObserverEntryInit: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try IntersectionObserverEntryImpl.constructor(state, intersectionObserverEntryInit);
        
        return instance;
    }

    pub fn get_time(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_time(state);
    }

    pub fn get_rootBounds(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_rootBounds(state);
    }

    pub fn get_boundingClientRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_boundingClientRect(state);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_intersectionRect(state);
    }

    pub fn get_isIntersecting(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_isIntersecting(state);
    }

    pub fn get_isVisible(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_isVisible(state);
    }

    pub fn get_intersectionRatio(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_intersectionRatio(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverEntryImpl.get_target(state);
    }

};

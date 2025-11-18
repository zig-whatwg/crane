//! Generated from: intersection-observer.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntersectionObserverImpl = @import("../impls/IntersectionObserver.zig");

pub const IntersectionObserver = struct {
    pub const Meta = struct {
        pub const name = "IntersectionObserver";
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
            root: ?(Element or Document) = null,
            rootMargin: runtime.DOMString = undefined,
            scrollMargin: runtime.DOMString = undefined,
            thresholds: FrozenArray<double> = undefined,
            delay: i32 = undefined,
            trackVisibility: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IntersectionObserver, .{
        .deinit_fn = &deinit_wrapper,

        .get_delay = &get_delay,
        .get_root = &get_root,
        .get_rootMargin = &get_rootMargin,
        .get_scrollMargin = &get_scrollMargin,
        .get_thresholds = &get_thresholds,
        .get_trackVisibility = &get_trackVisibility,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
        .call_unobserve = &call_unobserve,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IntersectionObserverImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IntersectionObserverImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try IntersectionObserverImpl.constructor(state, callback, options);
        
        return instance;
    }

    pub fn get_root(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverImpl.get_root(state);
    }

    pub fn get_rootMargin(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return IntersectionObserverImpl.get_rootMargin(state);
    }

    pub fn get_scrollMargin(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return IntersectionObserverImpl.get_scrollMargin(state);
    }

    pub fn get_thresholds(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverImpl.get_thresholds(state);
    }

    pub fn get_delay(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return IntersectionObserverImpl.get_delay(state);
    }

    pub fn get_trackVisibility(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IntersectionObserverImpl.get_trackVisibility(state);
    }

    pub fn call_observe(instance: *runtime.Instance, target: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IntersectionObserverImpl.call_observe(state, target);
    }

    pub fn call_unobserve(instance: *runtime.Instance, target: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return IntersectionObserverImpl.call_unobserve(state, target);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverImpl.call_disconnect(state);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IntersectionObserverImpl.call_takeRecords(state);
    }

};

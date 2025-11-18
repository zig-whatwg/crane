//! Generated from: intersection-observer.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntersectionObserverImpl = @import("impls").IntersectionObserver;
const IntersectionObserverInit = @import("dictionaries").IntersectionObserverInit;
const Element = @import("interfaces").Element;
const IntersectionObserverCallback = @import("callbacks").IntersectionObserverCallback;
const FrozenArray<double> = @import("interfaces").FrozenArray<double>;
const (Element or Document) = @import("interfaces").(Element or Document);

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
        
        // Initialize the instance (Impl receives full instance)
        IntersectionObserverImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IntersectionObserverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: IntersectionObserverCallback, options: IntersectionObserverInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try IntersectionObserverImpl.constructor(instance, callback, options);
        
        return instance;
    }

    pub fn get_root(instance: *runtime.Instance) anyerror!anyopaque {
        return try IntersectionObserverImpl.get_root(instance);
    }

    pub fn get_rootMargin(instance: *runtime.Instance) anyerror!DOMString {
        return try IntersectionObserverImpl.get_rootMargin(instance);
    }

    pub fn get_scrollMargin(instance: *runtime.Instance) anyerror!DOMString {
        return try IntersectionObserverImpl.get_scrollMargin(instance);
    }

    pub fn get_thresholds(instance: *runtime.Instance) anyerror!anyopaque {
        return try IntersectionObserverImpl.get_thresholds(instance);
    }

    pub fn get_delay(instance: *runtime.Instance) anyerror!i32 {
        return try IntersectionObserverImpl.get_delay(instance);
    }

    pub fn get_trackVisibility(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverImpl.get_trackVisibility(instance);
    }

    pub fn call_observe(instance: *runtime.Instance, target: Element) anyerror!void {
        
        return try IntersectionObserverImpl.call_observe(instance, target);
    }

    pub fn call_unobserve(instance: *runtime.Instance, target: Element) anyerror!void {
        
        return try IntersectionObserverImpl.call_unobserve(instance, target);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try IntersectionObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!anyopaque {
        return try IntersectionObserverImpl.call_takeRecords(instance);
    }

};

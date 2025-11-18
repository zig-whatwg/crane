//! Generated from: intersection-observer.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntersectionObserverEntryImpl = @import("impls").IntersectionObserverEntry;
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const IntersectionObserverEntryInit = @import("dictionaries").IntersectionObserverEntryInit;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;

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
        
        // Initialize the instance (Impl receives full instance)
        IntersectionObserverEntryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IntersectionObserverEntryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, intersectionObserverEntryInit: IntersectionObserverEntryInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try IntersectionObserverEntryImpl.constructor(instance, intersectionObserverEntryInit);
        
        return instance;
    }

    pub fn get_time(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try IntersectionObserverEntryImpl.get_time(instance);
    }

    pub fn get_rootBounds(instance: *runtime.Instance) anyerror!anyopaque {
        return try IntersectionObserverEntryImpl.get_rootBounds(instance);
    }

    pub fn get_boundingClientRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try IntersectionObserverEntryImpl.get_boundingClientRect(instance);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try IntersectionObserverEntryImpl.get_intersectionRect(instance);
    }

    pub fn get_isIntersecting(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverEntryImpl.get_isIntersecting(instance);
    }

    pub fn get_isVisible(instance: *runtime.Instance) anyerror!bool {
        return try IntersectionObserverEntryImpl.get_isVisible(instance);
    }

    pub fn get_intersectionRatio(instance: *runtime.Instance) anyerror!f64 {
        return try IntersectionObserverEntryImpl.get_intersectionRatio(instance);
    }

    pub fn get_target(instance: *runtime.Instance) anyerror!Element {
        return try IntersectionObserverEntryImpl.get_target(instance);
    }

};

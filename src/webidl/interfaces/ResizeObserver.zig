//! Generated from: resize-observer.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResizeObserverImpl = @import("impls").ResizeObserver;
const ResizeObserverCallback = @import("callbacks").ResizeObserverCallback;
const Element = @import("interfaces").Element;
const ResizeObserverOptions = @import("dictionaries").ResizeObserverOptions;

pub const ResizeObserver = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserver";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ResizeObserver, .{
        .deinit_fn = &deinit_wrapper,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
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
        ResizeObserverImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResizeObserverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: ResizeObserverCallback) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ResizeObserverImpl.constructor(instance, callback);
        
        return instance;
    }

    pub fn call_observe(instance: *runtime.Instance, target: Element, options: ResizeObserverOptions) anyerror!void {
        
        return try ResizeObserverImpl.call_observe(instance, target, options);
    }

    pub fn call_unobserve(instance: *runtime.Instance, target: Element) anyerror!void {
        
        return try ResizeObserverImpl.call_unobserve(instance, target);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try ResizeObserverImpl.call_disconnect(instance);
    }

};

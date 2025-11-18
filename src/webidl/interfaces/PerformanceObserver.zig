//! Generated from: performance-timeline.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceObserverImpl = @import("impls").PerformanceObserver;
const PerformanceEntryList = @import("typedefs").PerformanceEntryList;
const PerformanceObserverInit = @import("dictionaries").PerformanceObserverInit;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;
const PerformanceObserverCallback = @import("callbacks").PerformanceObserverCallback;

pub const PerformanceObserver = struct {
    pub const Meta = struct {
        pub const name = "PerformanceObserver";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceObserver, .{
        .deinit_fn = &deinit_wrapper,

        .get_supportedEntryTypes = &get_supportedEntryTypes,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PerformanceObserverImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceObserverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: PerformanceObserverCallback) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PerformanceObserverImpl.constructor(instance, callback);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_supportedEntryTypes(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_supportedEntryTypes) |cached| {
            return cached;
        }
        const value = try PerformanceObserverImpl.get_supportedEntryTypes(instance);
        state.cached_supportedEntryTypes = value;
        return value;
    }

    pub fn call_observe(instance: *runtime.Instance, options: PerformanceObserverInit) anyerror!void {
        
        return try PerformanceObserverImpl.call_observe(instance, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try PerformanceObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!PerformanceEntryList {
        return try PerformanceObserverImpl.call_takeRecords(instance);
    }

};

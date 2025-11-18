//! Generated from: performance-timeline.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceObserverImpl = @import("../impls/PerformanceObserver.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PerformanceObserverImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceObserverImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try PerformanceObserverImpl.constructor(state, callback);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_supportedEntryTypes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_supportedEntryTypes) |cached| {
            return cached;
        }
        const value = PerformanceObserverImpl.get_supportedEntryTypes(state);
        state.cached_supportedEntryTypes = value;
        return value;
    }

    pub fn call_observe(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceObserverImpl.call_observe(state, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceObserverImpl.call_disconnect(state);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceObserverImpl.call_takeRecords(state);
    }

};

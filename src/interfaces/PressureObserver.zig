//! Generated from: compute-pressure.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PressureObserverImpl = @import("../impls/PressureObserver.zig");

pub const PressureObserver = struct {
    pub const Meta = struct {
        pub const name = "PressureObserver";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PressureObserver, .{
        .deinit_fn = &deinit_wrapper,

        .get_knownSources = &get_knownSources,

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
        PressureObserverImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PressureObserverImpl.deinit(state);
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
        try PressureObserverImpl.constructor(state, callback);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_knownSources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_knownSources) |cached| {
            return cached;
        }
        const value = PressureObserverImpl.get_knownSources(state);
        state.cached_knownSources = value;
        return value;
    }

    pub fn call_observe(instance: *runtime.Instance, source: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PressureObserverImpl.call_observe(state, source, options);
    }

    pub fn call_unobserve(instance: *runtime.Instance, source: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PressureObserverImpl.call_unobserve(state, source);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PressureObserverImpl.call_disconnect(state);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PressureObserverImpl.call_takeRecords(state);
    }

};

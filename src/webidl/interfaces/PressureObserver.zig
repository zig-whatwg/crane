//! Generated from: compute-pressure.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PressureObserverImpl = @import("impls").PressureObserver;
const PressureSource = @import("enums").PressureSource;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const PressureObserverOptions = @import("dictionaries").PressureObserverOptions;
const FrozenArray<PressureSource> = @import("interfaces").FrozenArray<PressureSource>;
const PressureUpdateCallback = @import("callbacks").PressureUpdateCallback;

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
        
        // Initialize the instance (Impl receives full instance)
        PressureObserverImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PressureObserverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: PressureUpdateCallback) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try PressureObserverImpl.constructor(instance, callback);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_knownSources(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_knownSources) |cached| {
            return cached;
        }
        const value = try PressureObserverImpl.get_knownSources(instance);
        state.cached_knownSources = value;
        return value;
    }

    pub fn call_observe(instance: *runtime.Instance, source: PressureSource, options: PressureObserverOptions) anyerror!anyopaque {
        
        return try PressureObserverImpl.call_observe(instance, source, options);
    }

    pub fn call_unobserve(instance: *runtime.Instance, source: PressureSource) anyerror!void {
        
        return try PressureObserverImpl.call_unobserve(instance, source);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try PressureObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!anyopaque {
        return try PressureObserverImpl.call_takeRecords(instance);
    }

};

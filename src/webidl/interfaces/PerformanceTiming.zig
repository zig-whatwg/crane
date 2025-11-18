//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceTimingImpl = @import("impls").PerformanceTiming;

pub const PerformanceTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceTiming";
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
            navigationStart: u64 = undefined,
            unloadEventStart: u64 = undefined,
            unloadEventEnd: u64 = undefined,
            redirectStart: u64 = undefined,
            redirectEnd: u64 = undefined,
            fetchStart: u64 = undefined,
            domainLookupStart: u64 = undefined,
            domainLookupEnd: u64 = undefined,
            connectStart: u64 = undefined,
            connectEnd: u64 = undefined,
            secureConnectionStart: u64 = undefined,
            requestStart: u64 = undefined,
            responseStart: u64 = undefined,
            responseEnd: u64 = undefined,
            domLoading: u64 = undefined,
            domInteractive: u64 = undefined,
            domContentLoadedEventStart: u64 = undefined,
            domContentLoadedEventEnd: u64 = undefined,
            domComplete: u64 = undefined,
            loadEventStart: u64 = undefined,
            loadEventEnd: u64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_connectEnd = &get_connectEnd,
        .get_connectStart = &get_connectStart,
        .get_domComplete = &get_domComplete,
        .get_domContentLoadedEventEnd = &get_domContentLoadedEventEnd,
        .get_domContentLoadedEventStart = &get_domContentLoadedEventStart,
        .get_domInteractive = &get_domInteractive,
        .get_domLoading = &get_domLoading,
        .get_domainLookupEnd = &get_domainLookupEnd,
        .get_domainLookupStart = &get_domainLookupStart,
        .get_fetchStart = &get_fetchStart,
        .get_loadEventEnd = &get_loadEventEnd,
        .get_loadEventStart = &get_loadEventStart,
        .get_navigationStart = &get_navigationStart,
        .get_redirectEnd = &get_redirectEnd,
        .get_redirectStart = &get_redirectStart,
        .get_requestStart = &get_requestStart,
        .get_responseEnd = &get_responseEnd,
        .get_responseStart = &get_responseStart,
        .get_secureConnectionStart = &get_secureConnectionStart,
        .get_unloadEventEnd = &get_unloadEventEnd,
        .get_unloadEventStart = &get_unloadEventStart,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PerformanceTimingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_navigationStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_navigationStart(instance);
    }

    pub fn get_unloadEventStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_unloadEventStart(instance);
    }

    pub fn get_unloadEventEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_unloadEventEnd(instance);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_redirectStart(instance);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_redirectEnd(instance);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_fetchStart(instance);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domainLookupStart(instance);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domainLookupEnd(instance);
    }

    pub fn get_connectStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_connectStart(instance);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_connectEnd(instance);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_secureConnectionStart(instance);
    }

    pub fn get_requestStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_requestStart(instance);
    }

    pub fn get_responseStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_responseStart(instance);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_responseEnd(instance);
    }

    pub fn get_domLoading(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domLoading(instance);
    }

    pub fn get_domInteractive(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domInteractive(instance);
    }

    pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domContentLoadedEventStart(instance);
    }

    pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domContentLoadedEventEnd(instance);
    }

    pub fn get_domComplete(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_domComplete(instance);
    }

    pub fn get_loadEventStart(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_loadEventStart(instance);
    }

    pub fn get_loadEventEnd(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceTimingImpl.get_loadEventEnd(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceTimingImpl.call_toJSON(instance);
    }

};

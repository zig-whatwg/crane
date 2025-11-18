//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceTimingImpl = @import("../impls/PerformanceTiming.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PerformanceTimingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceTimingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_navigationStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_navigationStart(state);
    }

    pub fn get_unloadEventStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_unloadEventStart(state);
    }

    pub fn get_unloadEventEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_unloadEventEnd(state);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_redirectStart(state);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_redirectEnd(state);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_fetchStart(state);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domainLookupStart(state);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domainLookupEnd(state);
    }

    pub fn get_connectStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_connectStart(state);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_connectEnd(state);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_secureConnectionStart(state);
    }

    pub fn get_requestStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_requestStart(state);
    }

    pub fn get_responseStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_responseStart(state);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_responseEnd(state);
    }

    pub fn get_domLoading(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domLoading(state);
    }

    pub fn get_domInteractive(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domInteractive(state);
    }

    pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domContentLoadedEventStart(state);
    }

    pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domContentLoadedEventEnd(state);
    }

    pub fn get_domComplete(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_domComplete(state);
    }

    pub fn get_loadEventStart(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_loadEventStart(state);
    }

    pub fn get_loadEventEnd(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceTimingImpl.get_loadEventEnd(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceTimingImpl.call_toJSON(state);
    }

};

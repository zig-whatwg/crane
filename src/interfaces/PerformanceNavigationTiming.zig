//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceNavigationTimingImpl = @import("../impls/PerformanceNavigationTiming.zig");
const PerformanceResourceTiming = @import("PerformanceResourceTiming.zig");

pub const PerformanceNavigationTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceNavigationTiming";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceResourceTiming;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            unloadEventStart: DOMHighResTimeStamp = undefined,
            unloadEventEnd: DOMHighResTimeStamp = undefined,
            domInteractive: DOMHighResTimeStamp = undefined,
            domContentLoadedEventStart: DOMHighResTimeStamp = undefined,
            domContentLoadedEventEnd: DOMHighResTimeStamp = undefined,
            domComplete: DOMHighResTimeStamp = undefined,
            loadEventStart: DOMHighResTimeStamp = undefined,
            loadEventEnd: DOMHighResTimeStamp = undefined,
            type: NavigationTimingType = undefined,
            redirectCount: u16 = undefined,
            criticalCHRestart: DOMHighResTimeStamp = undefined,
            notRestoredReasons: ?NotRestoredReasons = null,
            activationStart: DOMHighResTimeStamp = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceNavigationTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_activationStart = &get_activationStart,
        .get_connectEnd = &get_connectEnd,
        .get_connectStart = &get_connectStart,
        .get_contentEncoding = &get_contentEncoding,
        .get_contentType = &get_contentType,
        .get_criticalCHRestart = &get_criticalCHRestart,
        .get_decodedBodySize = &get_decodedBodySize,
        .get_deliveryType = &get_deliveryType,
        .get_domComplete = &get_domComplete,
        .get_domContentLoadedEventEnd = &get_domContentLoadedEventEnd,
        .get_domContentLoadedEventStart = &get_domContentLoadedEventStart,
        .get_domInteractive = &get_domInteractive,
        .get_domainLookupEnd = &get_domainLookupEnd,
        .get_domainLookupStart = &get_domainLookupStart,
        .get_duration = &get_duration,
        .get_encodedBodySize = &get_encodedBodySize,
        .get_entryType = &get_entryType,
        .get_fetchStart = &get_fetchStart,
        .get_finalResponseHeadersStart = &get_finalResponseHeadersStart,
        .get_firstInterimResponseStart = &get_firstInterimResponseStart,
        .get_id = &get_id,
        .get_initiatorType = &get_initiatorType,
        .get_loadEventEnd = &get_loadEventEnd,
        .get_loadEventStart = &get_loadEventStart,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_nextHopProtocol = &get_nextHopProtocol,
        .get_notRestoredReasons = &get_notRestoredReasons,
        .get_redirectCount = &get_redirectCount,
        .get_redirectEnd = &get_redirectEnd,
        .get_redirectStart = &get_redirectStart,
        .get_renderBlockingStatus = &get_renderBlockingStatus,
        .get_requestStart = &get_requestStart,
        .get_responseEnd = &get_responseEnd,
        .get_responseStart = &get_responseStart,
        .get_responseStatus = &get_responseStatus,
        .get_secureConnectionStart = &get_secureConnectionStart,
        .get_serverTiming = &get_serverTiming,
        .get_startTime = &get_startTime,
        .get_transferSize = &get_transferSize,
        .get_type = &get_type,
        .get_unloadEventEnd = &get_unloadEventEnd,
        .get_unloadEventStart = &get_unloadEventStart,
        .get_workerStart = &get_workerStart,

        .call_toJSON = &call_toJSON,
        .call_toJSON = &call_toJSON,
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
        PerformanceNavigationTimingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceNavigationTimingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_navigationId(state);
    }

    pub fn get_initiatorType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_initiatorType(state);
    }

    pub fn get_deliveryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_deliveryType(state);
    }

    pub fn get_nextHopProtocol(instance: *runtime.Instance) runtime.ByteString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_nextHopProtocol(state);
    }

    pub fn get_workerStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_workerStart(state);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_redirectStart(state);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_redirectEnd(state);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_fetchStart(state);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_domainLookupStart(state);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_domainLookupEnd(state);
    }

    pub fn get_connectStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_connectStart(state);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_connectEnd(state);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_secureConnectionStart(state);
    }

    pub fn get_requestStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_requestStart(state);
    }

    pub fn get_finalResponseHeadersStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_finalResponseHeadersStart(state);
    }

    pub fn get_firstInterimResponseStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_firstInterimResponseStart(state);
    }

    pub fn get_responseStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_responseStart(state);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_responseEnd(state);
    }

    pub fn get_transferSize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_transferSize(state);
    }

    pub fn get_encodedBodySize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_encodedBodySize(state);
    }

    pub fn get_decodedBodySize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_decodedBodySize(state);
    }

    pub fn get_responseStatus(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_responseStatus(state);
    }

    pub fn get_renderBlockingStatus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_renderBlockingStatus(state);
    }

    pub fn get_contentType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_contentType(state);
    }

    pub fn get_contentEncoding(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_contentEncoding(state);
    }

    pub fn get_serverTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_serverTiming(state);
    }

    pub fn get_unloadEventStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_unloadEventStart(state);
    }

    pub fn get_unloadEventEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_unloadEventEnd(state);
    }

    pub fn get_domInteractive(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_domInteractive(state);
    }

    pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_domContentLoadedEventStart(state);
    }

    pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_domContentLoadedEventEnd(state);
    }

    pub fn get_domComplete(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_domComplete(state);
    }

    pub fn get_loadEventStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_loadEventStart(state);
    }

    pub fn get_loadEventEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_loadEventEnd(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_type(state);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_redirectCount(state);
    }

    pub fn get_criticalCHRestart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_criticalCHRestart(state);
    }

    pub fn get_notRestoredReasons(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_notRestoredReasons(state);
    }

    pub fn get_activationStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceNavigationTimingImpl.get_activationStart(state);
    }

    /// Arguments for toJSON (WebIDL overloading)
    pub const ToJSONArgs = union(enum) {
        /// toJSON()
        no_params: void,
        /// toJSON()
        no_params: void,
        /// toJSON()
        no_params: void,
    };

    pub fn call_toJSON(instance: *runtime.Instance, args: ToJSONArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return PerformanceNavigationTimingImpl.no_params(state),
            .no_params => return PerformanceNavigationTimingImpl.no_params(state),
            .no_params => return PerformanceNavigationTimingImpl.no_params(state),
        }
    }

};

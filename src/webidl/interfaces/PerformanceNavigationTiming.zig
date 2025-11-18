//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceNavigationTimingImpl = @import("impls").PerformanceNavigationTiming;
const PerformanceResourceTiming = @import("interfaces").PerformanceResourceTiming;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const NotRestoredReasons = @import("interfaces").NotRestoredReasons;
const NavigationTimingType = @import("enums").NavigationTimingType;

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PerformanceNavigationTimingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceNavigationTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceNavigationTimingImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceNavigationTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceNavigationTimingImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceNavigationTimingImpl.get_navigationId(instance);
    }

    pub fn get_initiatorType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceNavigationTimingImpl.get_initiatorType(instance);
    }

    pub fn get_deliveryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceNavigationTimingImpl.get_deliveryType(instance);
    }

    pub fn get_nextHopProtocol(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try PerformanceNavigationTimingImpl.get_nextHopProtocol(instance);
    }

    pub fn get_workerStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_workerStart(instance);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_redirectStart(instance);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_redirectEnd(instance);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_fetchStart(instance);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_domainLookupStart(instance);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_domainLookupEnd(instance);
    }

    pub fn get_connectStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_connectStart(instance);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_connectEnd(instance);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_secureConnectionStart(instance);
    }

    pub fn get_requestStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_requestStart(instance);
    }

    pub fn get_finalResponseHeadersStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_finalResponseHeadersStart(instance);
    }

    pub fn get_firstInterimResponseStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_firstInterimResponseStart(instance);
    }

    pub fn get_responseStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_responseStart(instance);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_responseEnd(instance);
    }

    pub fn get_transferSize(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceNavigationTimingImpl.get_transferSize(instance);
    }

    pub fn get_encodedBodySize(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceNavigationTimingImpl.get_encodedBodySize(instance);
    }

    pub fn get_decodedBodySize(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceNavigationTimingImpl.get_decodedBodySize(instance);
    }

    pub fn get_responseStatus(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationTimingImpl.get_responseStatus(instance);
    }

    pub fn get_renderBlockingStatus(instance: *runtime.Instance) anyerror!RenderBlockingStatusType {
        return try PerformanceNavigationTimingImpl.get_renderBlockingStatus(instance);
    }

    pub fn get_contentType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceNavigationTimingImpl.get_contentType(instance);
    }

    pub fn get_contentEncoding(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceNavigationTimingImpl.get_contentEncoding(instance);
    }

    pub fn get_serverTiming(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceNavigationTimingImpl.get_serverTiming(instance);
    }

    pub fn get_unloadEventStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_unloadEventStart(instance);
    }

    pub fn get_unloadEventEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_unloadEventEnd(instance);
    }

    pub fn get_domInteractive(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_domInteractive(instance);
    }

    pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_domContentLoadedEventStart(instance);
    }

    pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_domContentLoadedEventEnd(instance);
    }

    pub fn get_domComplete(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_domComplete(instance);
    }

    pub fn get_loadEventStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_loadEventStart(instance);
    }

    pub fn get_loadEventEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_loadEventEnd(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!NavigationTimingType {
        return try PerformanceNavigationTimingImpl.get_type(instance);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationTimingImpl.get_redirectCount(instance);
    }

    pub fn get_criticalCHRestart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_criticalCHRestart(instance);
    }

    pub fn get_notRestoredReasons(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceNavigationTimingImpl.get_notRestoredReasons(instance);
    }

    pub fn get_activationStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_activationStart(instance);
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

    pub fn call_toJSON(instance: *runtime.Instance, args: ToJSONArgs) anyerror!anyopaque {
        switch (args) {
            .no_params => return try PerformanceNavigationTimingImpl.no_params(instance),
            .no_params => return try PerformanceNavigationTimingImpl.no_params(instance),
            .no_params => return try PerformanceNavigationTimingImpl.no_params(instance),
        }
    }

};

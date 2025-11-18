//! Generated from: resource-timing.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceResourceTimingImpl = @import("impls").PerformanceResourceTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const FrozenArray<PerformanceServerTiming> = @import("interfaces").FrozenArray<PerformanceServerTiming>;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const RenderBlockingStatusType = @import("enums").RenderBlockingStatusType;

pub const PerformanceResourceTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceResourceTiming";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
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
        struct {
            initiatorType: runtime.DOMString = undefined,
            deliveryType: runtime.DOMString = undefined,
            nextHopProtocol: runtime.ByteString = undefined,
            workerStart: DOMHighResTimeStamp = undefined,
            redirectStart: DOMHighResTimeStamp = undefined,
            redirectEnd: DOMHighResTimeStamp = undefined,
            fetchStart: DOMHighResTimeStamp = undefined,
            domainLookupStart: DOMHighResTimeStamp = undefined,
            domainLookupEnd: DOMHighResTimeStamp = undefined,
            connectStart: DOMHighResTimeStamp = undefined,
            connectEnd: DOMHighResTimeStamp = undefined,
            secureConnectionStart: DOMHighResTimeStamp = undefined,
            requestStart: DOMHighResTimeStamp = undefined,
            finalResponseHeadersStart: DOMHighResTimeStamp = undefined,
            firstInterimResponseStart: DOMHighResTimeStamp = undefined,
            responseStart: DOMHighResTimeStamp = undefined,
            responseEnd: DOMHighResTimeStamp = undefined,
            transferSize: u64 = undefined,
            encodedBodySize: u64 = undefined,
            decodedBodySize: u64 = undefined,
            responseStatus: u16 = undefined,
            renderBlockingStatus: RenderBlockingStatusType = undefined,
            contentType: runtime.DOMString = undefined,
            contentEncoding: runtime.DOMString = undefined,
            serverTiming: FrozenArray<PerformanceServerTiming> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceResourceTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_connectEnd = &get_connectEnd,
        .get_connectStart = &get_connectStart,
        .get_contentEncoding = &get_contentEncoding,
        .get_contentType = &get_contentType,
        .get_decodedBodySize = &get_decodedBodySize,
        .get_deliveryType = &get_deliveryType,
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
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_nextHopProtocol = &get_nextHopProtocol,
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
        PerformanceResourceTimingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceResourceTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceResourceTimingImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceResourceTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceResourceTimingImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceResourceTimingImpl.get_navigationId(instance);
    }

    pub fn get_initiatorType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceResourceTimingImpl.get_initiatorType(instance);
    }

    pub fn get_deliveryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceResourceTimingImpl.get_deliveryType(instance);
    }

    pub fn get_nextHopProtocol(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try PerformanceResourceTimingImpl.get_nextHopProtocol(instance);
    }

    pub fn get_workerStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_workerStart(instance);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_redirectStart(instance);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_redirectEnd(instance);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_fetchStart(instance);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_domainLookupStart(instance);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_domainLookupEnd(instance);
    }

    pub fn get_connectStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_connectStart(instance);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_connectEnd(instance);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_secureConnectionStart(instance);
    }

    pub fn get_requestStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_requestStart(instance);
    }

    pub fn get_finalResponseHeadersStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_finalResponseHeadersStart(instance);
    }

    pub fn get_firstInterimResponseStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_firstInterimResponseStart(instance);
    }

    pub fn get_responseStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_responseStart(instance);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceResourceTimingImpl.get_responseEnd(instance);
    }

    pub fn get_transferSize(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceResourceTimingImpl.get_transferSize(instance);
    }

    pub fn get_encodedBodySize(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceResourceTimingImpl.get_encodedBodySize(instance);
    }

    pub fn get_decodedBodySize(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceResourceTimingImpl.get_decodedBodySize(instance);
    }

    pub fn get_responseStatus(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceResourceTimingImpl.get_responseStatus(instance);
    }

    pub fn get_renderBlockingStatus(instance: *runtime.Instance) anyerror!RenderBlockingStatusType {
        return try PerformanceResourceTimingImpl.get_renderBlockingStatus(instance);
    }

    pub fn get_contentType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceResourceTimingImpl.get_contentType(instance);
    }

    pub fn get_contentEncoding(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceResourceTimingImpl.get_contentEncoding(instance);
    }

    pub fn get_serverTiming(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceResourceTimingImpl.get_serverTiming(instance);
    }

    /// Arguments for toJSON (WebIDL overloading)
    pub const ToJSONArgs = union(enum) {
        /// toJSON()
        no_params: void,
        /// toJSON()
        no_params: void,
    };

    pub fn call_toJSON(instance: *runtime.Instance, args: ToJSONArgs) anyerror!anyopaque {
        switch (args) {
            .no_params => return try PerformanceResourceTimingImpl.no_params(instance),
            .no_params => return try PerformanceResourceTimingImpl.no_params(instance),
        }
    }

};

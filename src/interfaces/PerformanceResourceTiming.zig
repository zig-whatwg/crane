//! Generated from: resource-timing.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceResourceTimingImpl = @import("../impls/PerformanceResourceTiming.zig");
const PerformanceEntry = @import("PerformanceEntry.zig");

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
        PerformanceResourceTimingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceResourceTimingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_navigationId(state);
    }

    pub fn get_initiatorType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_initiatorType(state);
    }

    pub fn get_deliveryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_deliveryType(state);
    }

    pub fn get_nextHopProtocol(instance: *runtime.Instance) runtime.ByteString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_nextHopProtocol(state);
    }

    pub fn get_workerStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_workerStart(state);
    }

    pub fn get_redirectStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_redirectStart(state);
    }

    pub fn get_redirectEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_redirectEnd(state);
    }

    pub fn get_fetchStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_fetchStart(state);
    }

    pub fn get_domainLookupStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_domainLookupStart(state);
    }

    pub fn get_domainLookupEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_domainLookupEnd(state);
    }

    pub fn get_connectStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_connectStart(state);
    }

    pub fn get_connectEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_connectEnd(state);
    }

    pub fn get_secureConnectionStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_secureConnectionStart(state);
    }

    pub fn get_requestStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_requestStart(state);
    }

    pub fn get_finalResponseHeadersStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_finalResponseHeadersStart(state);
    }

    pub fn get_firstInterimResponseStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_firstInterimResponseStart(state);
    }

    pub fn get_responseStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_responseStart(state);
    }

    pub fn get_responseEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_responseEnd(state);
    }

    pub fn get_transferSize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_transferSize(state);
    }

    pub fn get_encodedBodySize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_encodedBodySize(state);
    }

    pub fn get_decodedBodySize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_decodedBodySize(state);
    }

    pub fn get_responseStatus(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_responseStatus(state);
    }

    pub fn get_renderBlockingStatus(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_renderBlockingStatus(state);
    }

    pub fn get_contentType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_contentType(state);
    }

    pub fn get_contentEncoding(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_contentEncoding(state);
    }

    pub fn get_serverTiming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceResourceTimingImpl.get_serverTiming(state);
    }

    /// Arguments for toJSON (WebIDL overloading)
    pub const ToJSONArgs = union(enum) {
        /// toJSON()
        no_params: void,
        /// toJSON()
        no_params: void,
    };

    pub fn call_toJSON(instance: *runtime.Instance, args: ToJSONArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return PerformanceResourceTimingImpl.no_params(state),
            .no_params => return PerformanceResourceTimingImpl.no_params(state),
        }
    }

};

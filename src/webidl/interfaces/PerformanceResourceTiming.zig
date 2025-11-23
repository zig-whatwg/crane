//! Generated from: resource-timing.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceResourceTimingImpl = @import("impls").PerformanceResourceTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const ByteString = @import("interfaces").ByteString;
const RenderBlockingStatusType = @import("enums").RenderBlockingStatusType;
const PerformanceServerTiming = @import("interfaces").PerformanceServerTiming;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceResourceTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceResourceTiming";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "initiatorType", "get_initiatorType", null },
            .{ "deliveryType", "get_deliveryType", null },
            .{ "nextHopProtocol", "get_nextHopProtocol", null },
            .{ "workerStart", "get_workerStart", null },
            .{ "redirectStart", "get_redirectStart", null },
            .{ "redirectEnd", "get_redirectEnd", null },
            .{ "fetchStart", "get_fetchStart", null },
            .{ "domainLookupStart", "get_domainLookupStart", null },
            .{ "domainLookupEnd", "get_domainLookupEnd", null },
            .{ "connectStart", "get_connectStart", null },
            .{ "connectEnd", "get_connectEnd", null },
            .{ "secureConnectionStart", "get_secureConnectionStart", null },
            .{ "requestStart", "get_requestStart", null },
            .{ "finalResponseHeadersStart", "get_finalResponseHeadersStart", null },
            .{ "firstInterimResponseStart", "get_firstInterimResponseStart", null },
            .{ "responseStart", "get_responseStart", null },
            .{ "responseEnd", "get_responseEnd", null },
            .{ "transferSize", "get_transferSize", null },
            .{ "encodedBodySize", "get_encodedBodySize", null },
            .{ "decodedBodySize", "get_decodedBodySize", null },
            .{ "responseStatus", "get_responseStatus", null },
            .{ "renderBlockingStatus", "get_renderBlockingStatus", null },
            .{ "contentType", "get_contentType", null },
            .{ "contentEncoding", "get_contentEncoding", null },
            .{ "serverTiming", "get_serverTiming", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "initiatorType", "get_initiatorType", null },
            .{ "deliveryType", "get_deliveryType", null },
            .{ "nextHopProtocol", "get_nextHopProtocol", null },
            .{ "workerStart", "get_workerStart", null },
            .{ "redirectStart", "get_redirectStart", null },
            .{ "redirectEnd", "get_redirectEnd", null },
            .{ "fetchStart", "get_fetchStart", null },
            .{ "domainLookupStart", "get_domainLookupStart", null },
            .{ "domainLookupEnd", "get_domainLookupEnd", null },
            .{ "connectStart", "get_connectStart", null },
            .{ "connectEnd", "get_connectEnd", null },
            .{ "secureConnectionStart", "get_secureConnectionStart", null },
            .{ "requestStart", "get_requestStart", null },
            .{ "finalResponseHeadersStart", "get_finalResponseHeadersStart", null },
            .{ "firstInterimResponseStart", "get_firstInterimResponseStart", null },
            .{ "responseStart", "get_responseStart", null },
            .{ "responseEnd", "get_responseEnd", null },
            .{ "transferSize", "get_transferSize", null },
            .{ "encodedBodySize", "get_encodedBodySize", null },
            .{ "decodedBodySize", "get_decodedBodySize", null },
            .{ "responseStatus", "get_responseStatus", null },
            .{ "renderBlockingStatus", "get_renderBlockingStatus", null },
            .{ "contentType", "get_contentType", null },
            .{ "contentEncoding", "get_contentEncoding", null },
            .{ "serverTiming", "get_serverTiming", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            serverTiming: runtime.FrozenArray(PerformanceServerTiming) = undefined,
        },
    );

    const delegates = .{

        .get_connectEnd = &get_connectEnd,
        .get_connectStart = &get_connectStart,
        .get_contentEncoding = &get_contentEncoding,
        .get_contentType = &get_contentType,
        .get_decodedBodySize = &get_decodedBodySize,
        .get_deliveryType = &get_deliveryType,
        .get_domainLookupEnd = &get_domainLookupEnd,
        .get_domainLookupStart = &get_domainLookupStart,
        .get_encodedBodySize = &get_encodedBodySize,
        .get_fetchStart = &get_fetchStart,
        .get_finalResponseHeadersStart = &get_finalResponseHeadersStart,
        .get_firstInterimResponseStart = &get_firstInterimResponseStart,
        .get_initiatorType = &get_initiatorType,
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
        .get_transferSize = &get_transferSize,
        .get_workerStart = &get_workerStart,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceResourceTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceResourceTimingImpl.deinit(instance);
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

    pub fn get_serverTiming(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceResourceTimingImpl.get_serverTiming(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceResourceTimingImpl.call_toJSON(instance);
    }

};

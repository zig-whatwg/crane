//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceTimingImpl = @import("impls").PerformanceTiming;

pub const PerformanceTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceTiming";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "navigationStart", "get_navigationStart", null },
            .{ "unloadEventStart", "get_unloadEventStart", null },
            .{ "unloadEventEnd", "get_unloadEventEnd", null },
            .{ "redirectStart", "get_redirectStart", null },
            .{ "redirectEnd", "get_redirectEnd", null },
            .{ "fetchStart", "get_fetchStart", null },
            .{ "domainLookupStart", "get_domainLookupStart", null },
            .{ "domainLookupEnd", "get_domainLookupEnd", null },
            .{ "connectStart", "get_connectStart", null },
            .{ "connectEnd", "get_connectEnd", null },
            .{ "secureConnectionStart", "get_secureConnectionStart", null },
            .{ "requestStart", "get_requestStart", null },
            .{ "responseStart", "get_responseStart", null },
            .{ "responseEnd", "get_responseEnd", null },
            .{ "domLoading", "get_domLoading", null },
            .{ "domInteractive", "get_domInteractive", null },
            .{ "domContentLoadedEventStart", "get_domContentLoadedEventStart", null },
            .{ "domContentLoadedEventEnd", "get_domContentLoadedEventEnd", null },
            .{ "domComplete", "get_domComplete", null },
            .{ "loadEventStart", "get_loadEventStart", null },
            .{ "loadEventEnd", "get_loadEventEnd", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "navigationStart", "get_navigationStart", null },
            .{ "unloadEventStart", "get_unloadEventStart", null },
            .{ "unloadEventEnd", "get_unloadEventEnd", null },
            .{ "redirectStart", "get_redirectStart", null },
            .{ "redirectEnd", "get_redirectEnd", null },
            .{ "fetchStart", "get_fetchStart", null },
            .{ "domainLookupStart", "get_domainLookupStart", null },
            .{ "domainLookupEnd", "get_domainLookupEnd", null },
            .{ "connectStart", "get_connectStart", null },
            .{ "connectEnd", "get_connectEnd", null },
            .{ "secureConnectionStart", "get_secureConnectionStart", null },
            .{ "requestStart", "get_requestStart", null },
            .{ "responseStart", "get_responseStart", null },
            .{ "responseEnd", "get_responseEnd", null },
            .{ "domLoading", "get_domLoading", null },
            .{ "domInteractive", "get_domInteractive", null },
            .{ "domContentLoadedEventStart", "get_domContentLoadedEventStart", null },
            .{ "domContentLoadedEventEnd", "get_domContentLoadedEventEnd", null },
            .{ "domComplete", "get_domComplete", null },
            .{ "loadEventStart", "get_loadEventStart", null },
            .{ "loadEventEnd", "get_loadEventEnd", null },
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
            _internal: ?*PerformanceTimingImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceTimingImpl.deinit(instance);
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
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceTimingImpl.call_toJSON(instance);
    }

};

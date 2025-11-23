//! Generated from: navigation-timing.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceNavigationTimingImpl = @import("impls").PerformanceNavigationTiming;
const PerformanceResourceTiming = @import("interfaces").PerformanceResourceTiming;
const ByteString = @import("interfaces").ByteString;
const NotRestoredReasons = @import("interfaces").NotRestoredReasons;
const PerformanceServerTiming = @import("interfaces").PerformanceServerTiming;
const RenderBlockingStatusType = @import("enums").RenderBlockingStatusType;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const NavigationTimingType = @import("enums").NavigationTimingType;
const DOMString = @import("typedefs").DOMString;

pub const PerformanceNavigationTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceNavigationTiming";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceResourceTiming;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "unloadEventStart", "get_unloadEventStart", null },
            .{ "unloadEventEnd", "get_unloadEventEnd", null },
            .{ "domInteractive", "get_domInteractive", null },
            .{ "domContentLoadedEventStart", "get_domContentLoadedEventStart", null },
            .{ "domContentLoadedEventEnd", "get_domContentLoadedEventEnd", null },
            .{ "domComplete", "get_domComplete", null },
            .{ "loadEventStart", "get_loadEventStart", null },
            .{ "loadEventEnd", "get_loadEventEnd", null },
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
            .{ "criticalCHRestart", "get_criticalCHRestart", null },
            .{ "notRestoredReasons", "get_notRestoredReasons", null },
            .{ "activationStart", "get_activationStart", null },
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
            .{ "unloadEventStart", "get_unloadEventStart", null },
            .{ "unloadEventEnd", "get_unloadEventEnd", null },
            .{ "domInteractive", "get_domInteractive", null },
            .{ "domContentLoadedEventStart", "get_domContentLoadedEventStart", null },
            .{ "domContentLoadedEventEnd", "get_domContentLoadedEventEnd", null },
            .{ "domComplete", "get_domComplete", null },
            .{ "loadEventStart", "get_loadEventStart", null },
            .{ "loadEventEnd", "get_loadEventEnd", null },
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
            .{ "criticalCHRestart", "get_criticalCHRestart", null },
            .{ "notRestoredReasons", "get_notRestoredReasons", null },
            .{ "activationStart", "get_activationStart", null },
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
            unloadEventStart: DOMHighResTimeStamp = undefined,
            unloadEventEnd: DOMHighResTimeStamp = undefined,
            domInteractive: DOMHighResTimeStamp = undefined,
            domContentLoadedEventStart: DOMHighResTimeStamp = undefined,
            domContentLoadedEventEnd: DOMHighResTimeStamp = undefined,
            domComplete: DOMHighResTimeStamp = undefined,
            loadEventStart: DOMHighResTimeStamp = undefined,
            loadEventEnd: DOMHighResTimeStamp = undefined,
            @"type": NavigationTimingType = undefined,
            redirectCount: u16 = undefined,
            criticalCHRestart: DOMHighResTimeStamp = undefined,
            notRestoredReasons: ?*runtime.Instance = null,
            activationStart: DOMHighResTimeStamp = undefined,
            _internal: ?*PerformanceNavigationTimingImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activationStart = &get_activationStart,
        .get_criticalCHRestart = &get_criticalCHRestart,
        .get_domComplete = &get_domComplete,
        .get_domContentLoadedEventEnd = &get_domContentLoadedEventEnd,
        .get_domContentLoadedEventStart = &get_domContentLoadedEventStart,
        .get_domInteractive = &get_domInteractive,
        .get_loadEventEnd = &get_loadEventEnd,
        .get_loadEventStart = &get_loadEventStart,
        .get_notRestoredReasons = &get_notRestoredReasons,
        .get_redirectCount = &get_redirectCount,
        .get_type = &get_type,
        .get_unloadEventEnd = &get_unloadEventEnd,
        .get_unloadEventStart = &get_unloadEventStart,

        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceNavigationTimingImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceNavigationTimingImpl.deinit(instance);
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

    pub fn get_notRestoredReasons(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PerformanceNavigationTimingImpl.get_notRestoredReasons(instance);
    }

    pub fn get_activationStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceNavigationTimingImpl.get_activationStart(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PerformanceNavigationTimingImpl.call_toJSON(instance);
    }

};

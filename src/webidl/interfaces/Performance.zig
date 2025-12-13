//! Generated from: hr-time.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceImpl = @import("impls").Performance;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PerformanceEntryList = @import("typedefs").PerformanceEntryList;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PerformanceMeasureOptions = @import("dictionaries").PerformanceMeasureOptions;
const PerformanceTiming = @import("interfaces").PerformanceTiming;
const EventCounts = @import("interfaces").EventCounts;
const MemoryMeasurement = @import("dictionaries").MemoryMeasurement;
const PerformanceMeasure = @import("interfaces").PerformanceMeasure;
const PerformanceMarkOptions = @import("dictionaries").PerformanceMarkOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const PerformanceNavigation = @import("interfaces").PerformanceNavigation;
const EventListener = @import("interfaces").EventListener;
const PerformanceMark = @import("interfaces").PerformanceMark;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const Performance = struct {
    pub const Meta = struct {
        pub const name = "Performance";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
            .{ "timeOrigin", "get_timeOrigin", null },
            .{ "eventCounts", "get_eventCounts", null },
            .{ "interactionCount", "get_interactionCount", null },
            .{ "timing", "get_timing", null },
            .{ "navigation", "get_navigation", null },
            .{ "onresourcetimingbufferfull", "get_onresourcetimingbufferfull", "set_onresourcetimingbufferfull" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "now", "call_now", 0 },
            .{ "toJSON", "call_toJSON", 0 },
            .{ "measureUserAgentSpecificMemory", "call_measureUserAgentSpecificMemory", 0 },
            .{ "getEntries", "call_getEntries", 0 },
            .{ "getEntriesByType", "call_getEntriesByType", 1 },
            .{ "getEntriesByName", "call_getEntriesByName", 1 },
            .{ "clearResourceTimings", "call_clearResourceTimings", 0 },
            .{ "setResourceTimingBufferSize", "call_setResourceTimingBufferSize", 1 },
            .{ "mark", "call_mark", 1 },
            .{ "clearMarks", "call_clearMarks", 0 },
            .{ "measure", "call_measure", 1 },
            .{ "clearMeasures", "call_clearMeasures", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "now",
            "toJSON",
            "measureUserAgentSpecificMemory",
            "getEntries",
            "getEntriesByType",
            "getEntriesByName",
            "clearResourceTimings",
            "setResourceTimingBufferSize",
            "mark",
            "clearMarks",
            "measure",
            "clearMeasures",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "timeOrigin", "get_timeOrigin", null },
            .{ "eventCounts", "get_eventCounts", null },
            .{ "interactionCount", "get_interactionCount", null },
            .{ "timing", "get_timing", null },
            .{ "navigation", "get_navigation", null },
            .{ "onresourcetimingbufferfull", "get_onresourcetimingbufferfull", "set_onresourcetimingbufferfull" },
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
            timeOrigin: DOMHighResTimeStamp = undefined,
            eventCounts: *runtime.Instance = undefined,
            interactionCount: u64 = undefined,
            timing: *runtime.Instance = undefined,
            navigation: *runtime.Instance = undefined,
            onresourcetimingbufferfull: EventHandler = undefined,
            cached_eventCounts: ?*runtime.Instance = null,
            cached_timing: ?*runtime.Instance = null,
            cached_navigation: ?*runtime.Instance = null,
            _internal: ?*PerformanceImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for Performance
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceToJSON = struct {
        timeOrigin: DOMHighResTimeStamp,
        eventCounts: EventCounts,
        interactionCount: u64,
        timing: PerformanceTiming,
        navigation: PerformanceNavigation,
        onresourcetimingbufferfull: EventHandler,
    };

    const delegates = .{

        .get_eventCounts = &get_eventCounts,
        .get_interactionCount = &get_interactionCount,
        .get_navigation = &get_navigation,
        .get_onresourcetimingbufferfull = &get_onresourcetimingbufferfull,
        .get_timeOrigin = &get_timeOrigin,
        .get_timing = &get_timing,

        .set_onresourcetimingbufferfull = &set_onresourcetimingbufferfull,

        .call_clearMarks = &call_clearMarks,
        .call_clearMeasures = &call_clearMeasures,
        .call_clearResourceTimings = &call_clearResourceTimings,
        .call_getEntries = &call_getEntries,
        .call_getEntriesByName = &call_getEntriesByName,
        .call_getEntriesByType = &call_getEntriesByType,
        .call_mark = &call_mark,
        .call_measure = &call_measure,
        .call_measureUserAgentSpecificMemory = &call_measureUserAgentSpecificMemory,
        .call_now = &call_now,
        .call_setResourceTimingBufferSize = &call_setResourceTimingBufferSize,
        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceImpl.deinit(instance);
    }

    pub fn get_timeOrigin(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceImpl.get_timeOrigin(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_eventCounts(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_eventCounts) |cached| {
            return cached;
        }
        const value = try PerformanceImpl.get_eventCounts(instance);
        state.own.cached_eventCounts = value;
        return value;
    }

    pub fn get_interactionCount(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceImpl.get_interactionCount(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_timing(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_timing) |cached| {
            return cached;
        }
        const value = try PerformanceImpl.get_timing(instance);
        state.own.cached_timing = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_navigation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_navigation) |cached| {
            return cached;
        }
        const value = try PerformanceImpl.get_navigation(instance);
        state.own.cached_navigation = value;
        return value;
    }

    pub fn get_onresourcetimingbufferfull(instance: *runtime.Instance) anyerror!EventHandler {
        return try PerformanceImpl.get_onresourcetimingbufferfull(instance);
    }

    pub fn set_onresourcetimingbufferfull(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PerformanceImpl.set_onresourcetimingbufferfull(instance, value);
    }

    pub fn call_clearResourceTimings(instance: *runtime.Instance) anyerror!void {
        return try PerformanceImpl.call_clearResourceTimings(instance);
    }

    pub fn call_clearMeasures(instance: *runtime.Instance, measureName: webidl.Opt(DOMString)) anyerror!void {
        
        return try PerformanceImpl.call_clearMeasures(instance, measureName);
    }

    pub fn call_mark(instance: *runtime.Instance, markName: DOMString, markOptions: webidl.Opt(PerformanceMarkOptions)) anyerror!*runtime.Instance {
        
        return try PerformanceImpl.call_mark(instance, markName, markOptions);
    }

    pub fn call_getEntriesByName(instance: *runtime.Instance, name: DOMString, @"type": webidl.Opt(DOMString)) anyerror!PerformanceEntryList {
        
        return try PerformanceImpl.call_getEntriesByName(instance, name, @"type");
    }

    pub fn call_setResourceTimingBufferSize(instance: *runtime.Instance, maxSize: u32) anyerror!void {
        
        return try PerformanceImpl.call_setResourceTimingBufferSize(instance, maxSize);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PerformanceImpl.call_toJSON(instance);
    }

    pub fn call_measure(instance: *runtime.Instance, measureName: DOMString, startOrMeasureOptions: webidl.Opt(runtime.JSValue), endMark: webidl.Opt(DOMString)) anyerror!*runtime.Instance {
        
        return try PerformanceImpl.call_measure(instance, measureName, startOrMeasureOptions, endMark);
    }

    pub fn call_now(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceImpl.call_now(instance);
    }

    pub fn call_getEntries(instance: *runtime.Instance) anyerror!PerformanceEntryList {
        return try PerformanceImpl.call_getEntries(instance);
    }

    pub fn call_clearMarks(instance: *runtime.Instance, markName: webidl.Opt(DOMString)) anyerror!void {
        
        return try PerformanceImpl.call_clearMarks(instance, markName);
    }

    pub fn call_getEntriesByType(instance: *runtime.Instance, @"type": DOMString) anyerror!PerformanceEntryList {
        
        return try PerformanceImpl.call_getEntriesByType(instance, @"type");
    }

    /// Extended attributes: [Exposed=(Window,ServiceWorker,SharedWorker)], [CrossOriginIsolated]
    pub fn call_measureUserAgentSpecificMemory(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PerformanceImpl.call_measureUserAgentSpecificMemory(instance);
    }

};

//! Generated from: hr-time.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceImpl = @import("impls").Performance;
const EventTarget = @import("interfaces").EventTarget;
const PerformanceMark = @import("interfaces").PerformanceMark;
const PerformanceMeasure = @import("interfaces").PerformanceMeasure;
const PerformanceEntryList = @import("typedefs").PerformanceEntryList;
const PerformanceMarkOptions = @import("dictionaries").PerformanceMarkOptions;
const PerformanceNavigation = @import("interfaces").PerformanceNavigation;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Promise<MemoryMeasurement> = @import("interfaces").Promise<MemoryMeasurement>;
const (DOMString or PerformanceMeasureOptions) = @import("interfaces").(DOMString or PerformanceMeasureOptions);
const EventCounts = @import("interfaces").EventCounts;
const PerformanceTiming = @import("interfaces").PerformanceTiming;
const EventHandler = @import("typedefs").EventHandler;

pub const Performance = struct {
    pub const Meta = struct {
        pub const name = "Performance";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            timeOrigin: DOMHighResTimeStamp = undefined,
            eventCounts: EventCounts = undefined,
            interactionCount: u64 = undefined,
            timing: PerformanceTiming = undefined,
            navigation: PerformanceNavigation = undefined,
            onresourcetimingbufferfull: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Performance, .{
        .deinit_fn = &deinit_wrapper,

        .get_eventCounts = &get_eventCounts,
        .get_interactionCount = &get_interactionCount,
        .get_navigation = &get_navigation,
        .get_onresourcetimingbufferfull = &get_onresourcetimingbufferfull,
        .get_timeOrigin = &get_timeOrigin,
        .get_timing = &get_timing,

        .set_onresourcetimingbufferfull = &set_onresourcetimingbufferfull,

        .call_addEventListener = &call_addEventListener,
        .call_clearMarks = &call_clearMarks,
        .call_clearMeasures = &call_clearMeasures,
        .call_clearResourceTimings = &call_clearResourceTimings,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getEntries = &call_getEntries,
        .call_getEntriesByName = &call_getEntriesByName,
        .call_getEntriesByType = &call_getEntriesByType,
        .call_mark = &call_mark,
        .call_measure = &call_measure,
        .call_measureUserAgentSpecificMemory = &call_measureUserAgentSpecificMemory,
        .call_now = &call_now,
        .call_removeEventListener = &call_removeEventListener,
        .call_setResourceTimingBufferSize = &call_setResourceTimingBufferSize,
        .call_toJSON = &call_toJSON,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PerformanceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_timeOrigin(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceImpl.get_timeOrigin(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_eventCounts(instance: *runtime.Instance) anyerror!EventCounts {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_eventCounts) |cached| {
            return cached;
        }
        const value = try PerformanceImpl.get_eventCounts(instance);
        state.cached_eventCounts = value;
        return value;
    }

    pub fn get_interactionCount(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceImpl.get_interactionCount(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_timing(instance: *runtime.Instance) anyerror!PerformanceTiming {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_timing) |cached| {
            return cached;
        }
        const value = try PerformanceImpl.get_timing(instance);
        state.cached_timing = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_navigation(instance: *runtime.Instance) anyerror!PerformanceNavigation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_navigation) |cached| {
            return cached;
        }
        const value = try PerformanceImpl.get_navigation(instance);
        state.cached_navigation = value;
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

    pub fn call_clearMeasures(instance: *runtime.Instance, measureName: DOMString) anyerror!void {
        
        return try PerformanceImpl.call_clearMeasures(instance, measureName);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PerformanceImpl.call_when(instance, type_, options);
    }

    pub fn call_setResourceTimingBufferSize(instance: *runtime.Instance, maxSize: u32) anyerror!void {
        
        return try PerformanceImpl.call_setResourceTimingBufferSize(instance, maxSize);
    }

    pub fn call_now(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceImpl.call_now(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceImpl.call_toJSON(instance);
    }

    /// Extended attributes: [Exposed=(Window,ServiceWorker,SharedWorker)], [CrossOriginIsolated]
    pub fn call_measureUserAgentSpecificMemory(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceImpl.call_measureUserAgentSpecificMemory(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PerformanceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PerformanceImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_clearMarks(instance: *runtime.Instance, markName: DOMString) anyerror!void {
        
        return try PerformanceImpl.call_clearMarks(instance, markName);
    }

    pub fn call_getEntriesByType(instance: *runtime.Instance, type_: DOMString) anyerror!PerformanceEntryList {
        
        return try PerformanceImpl.call_getEntriesByType(instance, type_);
    }

    pub fn call_mark(instance: *runtime.Instance, markName: DOMString, markOptions: PerformanceMarkOptions) anyerror!PerformanceMark {
        
        return try PerformanceImpl.call_mark(instance, markName, markOptions);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PerformanceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getEntries(instance: *runtime.Instance) anyerror!PerformanceEntryList {
        return try PerformanceImpl.call_getEntries(instance);
    }

    pub fn call_measure(instance: *runtime.Instance, measureName: DOMString, startOrMeasureOptions: anyopaque, endMark: DOMString) anyerror!PerformanceMeasure {
        
        return try PerformanceImpl.call_measure(instance, measureName, startOrMeasureOptions, endMark);
    }

    pub fn call_getEntriesByName(instance: *runtime.Instance, name: DOMString, type_: DOMString) anyerror!PerformanceEntryList {
        
        return try PerformanceImpl.call_getEntriesByName(instance, name, type_);
    }

};

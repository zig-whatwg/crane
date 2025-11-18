//! Generated from: hr-time.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceImpl = @import("../impls/Performance.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PerformanceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_timeOrigin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.get_timeOrigin(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_eventCounts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_eventCounts) |cached| {
            return cached;
        }
        const value = PerformanceImpl.get_eventCounts(state);
        state.cached_eventCounts = value;
        return value;
    }

    pub fn get_interactionCount(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceImpl.get_interactionCount(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_timing(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_timing) |cached| {
            return cached;
        }
        const value = PerformanceImpl.get_timing(state);
        state.cached_timing = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_navigation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_navigation) |cached| {
            return cached;
        }
        const value = PerformanceImpl.get_navigation(state);
        state.cached_navigation = value;
        return value;
    }

    pub fn get_onresourcetimingbufferfull(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.get_onresourcetimingbufferfull(state);
    }

    pub fn set_onresourcetimingbufferfull(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PerformanceImpl.set_onresourcetimingbufferfull(state, value);
    }

    pub fn call_clearResourceTimings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.call_clearResourceTimings(state);
    }

    pub fn call_clearMeasures(instance: *runtime.Instance, measureName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_clearMeasures(state, measureName);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_when(state, type_, options);
    }

    pub fn call_setResourceTimingBufferSize(instance: *runtime.Instance, maxSize: u32) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_setResourceTimingBufferSize(state, maxSize);
    }

    pub fn call_now(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.call_now(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.call_toJSON(state);
    }

    /// Extended attributes: [Exposed=(Window,ServiceWorker,SharedWorker)], [CrossOriginIsolated]
    pub fn call_measureUserAgentSpecificMemory(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.call_measureUserAgentSpecificMemory(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_clearMarks(instance: *runtime.Instance, markName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_clearMarks(state, markName);
    }

    pub fn call_getEntriesByType(instance: *runtime.Instance, type_: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_getEntriesByType(state, type_);
    }

    pub fn call_mark(instance: *runtime.Instance, markName: runtime.DOMString, markOptions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_mark(state, markName, markOptions);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getEntries(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceImpl.call_getEntries(state);
    }

    pub fn call_measure(instance: *runtime.Instance, measureName: runtime.DOMString, startOrMeasureOptions: anyopaque, endMark: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_measure(state, measureName, startOrMeasureOptions, endMark);
    }

    pub fn call_getEntriesByName(instance: *runtime.Instance, name: runtime.DOMString, type_: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PerformanceImpl.call_getEntriesByName(state, name, type_);
    }

};

//! Generated from: event-timing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceEventTimingImpl = @import("../impls/PerformanceEventTiming.zig");
const PerformanceEntry = @import("PerformanceEntry.zig");

pub const PerformanceEventTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceEventTiming";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            processingStart: DOMHighResTimeStamp = undefined,
            processingEnd: DOMHighResTimeStamp = undefined,
            cancelable: bool = undefined,
            target: ?Node = null,
            interactionId: u64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceEventTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_cancelable = &get_cancelable,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_id = &get_id,
        .get_interactionId = &get_interactionId,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_processingEnd = &get_processingEnd,
        .get_processingStart = &get_processingStart,
        .get_startTime = &get_startTime,
        .get_target = &get_target,

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
        PerformanceEventTimingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceEventTimingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_navigationId(state);
    }

    pub fn get_processingStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_processingStart(state);
    }

    pub fn get_processingEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_processingEnd(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_cancelable(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_target(state);
    }

    pub fn get_interactionId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceEventTimingImpl.get_interactionId(state);
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
            .no_params => return PerformanceEventTimingImpl.no_params(state),
            .no_params => return PerformanceEventTimingImpl.no_params(state),
        }
    }

};

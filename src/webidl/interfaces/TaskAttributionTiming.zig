//! Generated from: longtasks.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskAttributionTimingImpl = @import("impls").TaskAttributionTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;

pub const TaskAttributionTiming = struct {
    pub const Meta = struct {
        pub const name = "TaskAttributionTiming";
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
            startTime: DOMHighResTimeStamp = undefined,
            duration: DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            containerType: runtime.DOMString = undefined,
            containerSrc: runtime.DOMString = undefined,
            containerId: runtime.DOMString = undefined,
            containerName: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TaskAttributionTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_containerId = &get_containerId,
        .get_containerName = &get_containerName,
        .get_containerSrc = &get_containerSrc,
        .get_containerType = &get_containerType,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_startTime = &get_startTime,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return TaskAttributionTimingImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskAttributionTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try TaskAttributionTimingImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try TaskAttributionTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try TaskAttributionTimingImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try TaskAttributionTimingImpl.get_navigationId(instance);
    }

    pub fn get_containerType(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerType(instance);
    }

    pub fn get_containerSrc(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerSrc(instance);
    }

    pub fn get_containerId(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerId(instance);
    }

    pub fn get_containerName(instance: *runtime.Instance) anyerror!DOMString {
        return try TaskAttributionTimingImpl.get_containerName(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try TaskAttributionTimingImpl.call_toJSON(instance);
    }

};

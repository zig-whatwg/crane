//! Generated from: user-timing.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceMeasureImpl = @import("../impls/PerformanceMeasure.zig");
const PerformanceEntry = @import("PerformanceEntry.zig");

pub const PerformanceMeasure = struct {
    pub const Meta = struct {
        pub const name = "PerformanceMeasure";
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
            detail: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceMeasure, .{
        .deinit_fn = &deinit_wrapper,

        .get_detail = &get_detail,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PerformanceMeasureImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformanceMeasureImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_navigationId(state);
    }

    pub fn get_detail(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.get_detail(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformanceMeasureImpl.call_toJSON(state);
    }

};

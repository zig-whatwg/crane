//! Generated from: paint-timing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformancePaintTimingImpl = @import("../impls/PerformancePaintTiming.zig");
const PerformanceEntry = @import("PerformanceEntry.zig");
const PaintTimingMixin = @import("PaintTimingMixin.zig");

pub const PerformancePaintTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformancePaintTiming";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PerformanceEntry;
        pub const MixinTypes = .{
            PaintTimingMixin,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformancePaintTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_startTime = &get_startTime,

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
        PerformancePaintTimingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PerformancePaintTimingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_navigationId(state);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_paintTime(state);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PerformancePaintTimingImpl.get_presentationTime(state);
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
            .no_params => return PerformancePaintTimingImpl.no_params(state),
            .no_params => return PerformancePaintTimingImpl.no_params(state),
        }
    }

};

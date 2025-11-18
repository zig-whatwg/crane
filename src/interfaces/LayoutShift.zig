//! Generated from: layout-instability.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutShiftImpl = @import("../impls/LayoutShift.zig");
const PerformanceEntry = @import("PerformanceEntry.zig");

pub const LayoutShift = struct {
    pub const Meta = struct {
        pub const name = "LayoutShift";
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
            value: f64 = undefined,
            hadRecentInput: bool = undefined,
            lastInputTime: DOMHighResTimeStamp = undefined,
            sources: FrozenArray<LayoutShiftAttribution> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutShift, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_hadRecentInput = &get_hadRecentInput,
        .get_id = &get_id,
        .get_lastInputTime = &get_lastInputTime,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_sources = &get_sources,
        .get_startTime = &get_startTime,
        .get_value = &get_value,

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
        LayoutShiftImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LayoutShiftImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_navigationId(state);
    }

    pub fn get_value(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_value(state);
    }

    pub fn get_hadRecentInput(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_hadRecentInput(state);
    }

    pub fn get_lastInputTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_lastInputTime(state);
    }

    pub fn get_sources(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LayoutShiftImpl.get_sources(state);
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
            .no_params => return LayoutShiftImpl.no_params(state),
            .no_params => return LayoutShiftImpl.no_params(state),
        }
    }

};

//! Generated from: layout-instability.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutShiftImpl = @import("impls").LayoutShift;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const FrozenArray<LayoutShiftAttribution> = @import("interfaces").FrozenArray<LayoutShiftAttribution>;

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LayoutShiftImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutShiftImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try LayoutShiftImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try LayoutShiftImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try LayoutShiftImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LayoutShiftImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LayoutShiftImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try LayoutShiftImpl.get_navigationId(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutShiftImpl.get_value(instance);
    }

    pub fn get_hadRecentInput(instance: *runtime.Instance) anyerror!bool {
        return try LayoutShiftImpl.get_hadRecentInput(instance);
    }

    pub fn get_lastInputTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LayoutShiftImpl.get_lastInputTime(instance);
    }

    pub fn get_sources(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutShiftImpl.get_sources(instance);
    }

    /// Arguments for toJSON (WebIDL overloading)
    pub const ToJSONArgs = union(enum) {
        /// toJSON()
        no_params: void,
        /// toJSON()
        no_params: void,
    };

    pub fn call_toJSON(instance: *runtime.Instance, args: ToJSONArgs) anyerror!anyopaque {
        switch (args) {
            .no_params => return try LayoutShiftImpl.no_params(instance),
            .no_params => return try LayoutShiftImpl.no_params(instance),
        }
    }

};

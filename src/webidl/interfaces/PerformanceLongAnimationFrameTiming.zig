//! Generated from: long-animation-frames.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceLongAnimationFrameTimingImpl = @import("impls").PerformanceLongAnimationFrameTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("interfaces").PaintTimingMixin;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const FrozenArray<PerformanceScriptTiming> = @import("interfaces").FrozenArray<PerformanceScriptTiming>;

pub const PerformanceLongAnimationFrameTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceLongAnimationFrameTiming";
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
            startTime: DOMHighResTimeStamp = undefined,
            duration: DOMHighResTimeStamp = undefined,
            name: runtime.DOMString = undefined,
            entryType: runtime.DOMString = undefined,
            renderStart: DOMHighResTimeStamp = undefined,
            styleAndLayoutStart: DOMHighResTimeStamp = undefined,
            blockingDuration: DOMHighResTimeStamp = undefined,
            firstUIEventTimestamp: DOMHighResTimeStamp = undefined,
            scripts: FrozenArray<PerformanceScriptTiming> = undefined,
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceLongAnimationFrameTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_blockingDuration = &get_blockingDuration,
        .get_duration = &get_duration,
        .get_duration = &get_duration,
        .get_entryType = &get_entryType,
        .get_entryType = &get_entryType,
        .get_firstUIEventTimestamp = &get_firstUIEventTimestamp,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderStart = &get_renderStart,
        .get_scripts = &get_scripts,
        .get_startTime = &get_startTime,
        .get_startTime = &get_startTime,
        .get_styleAndLayoutStart = &get_styleAndLayoutStart,

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
        PerformanceLongAnimationFrameTimingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceLongAnimationFrameTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceLongAnimationFrameTimingImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceLongAnimationFrameTimingImpl.get_navigationId(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_duration(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceLongAnimationFrameTimingImpl.get_entryType(instance);
    }

    pub fn get_renderStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_renderStart(instance);
    }

    pub fn get_styleAndLayoutStart(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_styleAndLayoutStart(instance);
    }

    pub fn get_blockingDuration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_blockingDuration(instance);
    }

    pub fn get_firstUIEventTimestamp(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_firstUIEventTimestamp(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_scripts(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_scripts) |cached| {
            return cached;
        }
        const value = try PerformanceLongAnimationFrameTimingImpl.get_scripts(instance);
        state.cached_scripts = value;
        return value;
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceLongAnimationFrameTimingImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceLongAnimationFrameTimingImpl.get_presentationTime(instance);
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
            .no_params => return try PerformanceLongAnimationFrameTimingImpl.no_params(instance),
            .no_params => return try PerformanceLongAnimationFrameTimingImpl.no_params(instance),
        }
    }

};

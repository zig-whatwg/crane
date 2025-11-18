//! Generated from: element-timing.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceElementTimingImpl = @import("impls").PerformanceElementTiming;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("interfaces").PaintTimingMixin;
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;

pub const PerformanceElementTiming = struct {
    pub const Meta = struct {
        pub const name = "PerformanceElementTiming";
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
            renderTime: DOMHighResTimeStamp = undefined,
            loadTime: DOMHighResTimeStamp = undefined,
            intersectionRect: DOMRectReadOnly = undefined,
            identifier: runtime.DOMString = undefined,
            naturalWidth: u32 = undefined,
            naturalHeight: u32 = undefined,
            id: runtime.DOMString = undefined,
            element: ?Element = null,
            url: runtime.USVString = undefined,
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PerformanceElementTiming, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_element = &get_element,
        .get_entryType = &get_entryType,
        .get_id = &get_id,
        .get_id = &get_id,
        .get_identifier = &get_identifier,
        .get_intersectionRect = &get_intersectionRect,
        .get_loadTime = &get_loadTime,
        .get_name = &get_name,
        .get_naturalHeight = &get_naturalHeight,
        .get_naturalWidth = &get_naturalWidth,
        .get_navigationId = &get_navigationId,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderTime = &get_renderTime,
        .get_startTime = &get_startTime,
        .get_url = &get_url,

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
        PerformanceElementTimingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceElementTimingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceElementTimingImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceElementTimingImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceElementTimingImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try PerformanceElementTimingImpl.get_navigationId(instance);
    }

    pub fn get_renderTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_renderTime(instance);
    }

    pub fn get_loadTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_loadTime(instance);
    }

    pub fn get_intersectionRect(instance: *runtime.Instance) anyerror!DOMRectReadOnly {
        return try PerformanceElementTimingImpl.get_intersectionRect(instance);
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceElementTimingImpl.get_identifier(instance);
    }

    pub fn get_naturalWidth(instance: *runtime.Instance) anyerror!u32 {
        return try PerformanceElementTimingImpl.get_naturalWidth(instance);
    }

    pub fn get_naturalHeight(instance: *runtime.Instance) anyerror!u32 {
        return try PerformanceElementTimingImpl.get_naturalHeight(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try PerformanceElementTimingImpl.get_id(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceElementTimingImpl.get_element(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PerformanceElementTimingImpl.get_url(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PerformanceElementTimingImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try PerformanceElementTimingImpl.get_presentationTime(instance);
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
            .no_params => return try PerformanceElementTimingImpl.no_params(instance),
            .no_params => return try PerformanceElementTimingImpl.no_params(instance),
        }
    }

};

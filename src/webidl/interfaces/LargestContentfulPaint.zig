//! Generated from: largest-contentful-paint.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LargestContentfulPaintImpl = @import("impls").LargestContentfulPaint;
const PerformanceEntry = @import("interfaces").PerformanceEntry;
const PaintTimingMixin = @import("interfaces").PaintTimingMixin;
const Element = @import("interfaces").Element;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;

pub const LargestContentfulPaint = struct {
    pub const Meta = struct {
        pub const name = "LargestContentfulPaint";
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
            loadTime: DOMHighResTimeStamp = undefined,
            renderTime: DOMHighResTimeStamp = undefined,
            size: u32 = undefined,
            id: runtime.DOMString = undefined,
            url: runtime.DOMString = undefined,
            element: ?Element = null,
            paintTime: DOMHighResTimeStamp = undefined,
            presentationTime: ?DOMHighResTimeStamp = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LargestContentfulPaint, .{
        .deinit_fn = &deinit_wrapper,

        .get_duration = &get_duration,
        .get_element = &get_element,
        .get_entryType = &get_entryType,
        .get_id = &get_id,
        .get_id = &get_id,
        .get_loadTime = &get_loadTime,
        .get_name = &get_name,
        .get_navigationId = &get_navigationId,
        .get_paintTime = &get_paintTime,
        .get_presentationTime = &get_presentationTime,
        .get_renderTime = &get_renderTime,
        .get_size = &get_size,
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
        LargestContentfulPaintImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LargestContentfulPaintImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u64 {
        return try LargestContentfulPaintImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_name(instance);
    }

    pub fn get_entryType(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_entryType(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_startTime(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_duration(instance);
    }

    pub fn get_navigationId(instance: *runtime.Instance) anyerror!u64 {
        return try LargestContentfulPaintImpl.get_navigationId(instance);
    }

    pub fn get_loadTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_loadTime(instance);
    }

    pub fn get_renderTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_renderTime(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try LargestContentfulPaintImpl.get_size(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_id(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!DOMString {
        return try LargestContentfulPaintImpl.get_url(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!anyopaque {
        return try LargestContentfulPaintImpl.get_element(instance);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try LargestContentfulPaintImpl.get_paintTime(instance);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try LargestContentfulPaintImpl.get_presentationTime(instance);
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
            .no_params => return try LargestContentfulPaintImpl.no_params(instance),
            .no_params => return try LargestContentfulPaintImpl.no_params(instance),
        }
    }

};

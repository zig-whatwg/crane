//! Generated from: largest-contentful-paint.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LargestContentfulPaintImpl = @import("../impls/LargestContentfulPaint.zig");
const PerformanceEntry = @import("PerformanceEntry.zig");
const PaintTimingMixin = @import("PaintTimingMixin.zig");

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
        LargestContentfulPaintImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LargestContentfulPaintImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_id(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_name(state);
    }

    pub fn get_entryType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_entryType(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_startTime(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_duration(state);
    }

    pub fn get_navigationId(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_navigationId(state);
    }

    pub fn get_loadTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_loadTime(state);
    }

    pub fn get_renderTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_renderTime(state);
    }

    pub fn get_size(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_size(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_id(state);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_url(state);
    }

    pub fn get_element(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_element(state);
    }

    pub fn get_paintTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_paintTime(state);
    }

    pub fn get_presentationTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LargestContentfulPaintImpl.get_presentationTime(state);
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
            .no_params => return LargestContentfulPaintImpl.no_params(state),
            .no_params => return LargestContentfulPaintImpl.no_params(state),
        }
    }

};

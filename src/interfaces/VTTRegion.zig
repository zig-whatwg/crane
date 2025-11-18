//! Generated from: webvtt.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VTTRegionImpl = @import("../impls/VTTRegion.zig");

pub const VTTRegion = struct {
    pub const Meta = struct {
        pub const name = "VTTRegion";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            id: runtime.DOMString = undefined,
            width: f64 = undefined,
            lines: u32 = undefined,
            regionAnchorX: f64 = undefined,
            regionAnchorY: f64 = undefined,
            viewportAnchorX: f64 = undefined,
            viewportAnchorY: f64 = undefined,
            scroll: ScrollSetting = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VTTRegion, .{
        .deinit_fn = &deinit_wrapper,

        .get_id = &get_id,
        .get_lines = &get_lines,
        .get_regionAnchorX = &get_regionAnchorX,
        .get_regionAnchorY = &get_regionAnchorY,
        .get_scroll = &get_scroll,
        .get_viewportAnchorX = &get_viewportAnchorX,
        .get_viewportAnchorY = &get_viewportAnchorY,
        .get_width = &get_width,

        .set_id = &set_id,
        .set_lines = &set_lines,
        .set_regionAnchorX = &set_regionAnchorX,
        .set_regionAnchorY = &set_regionAnchorY,
        .set_scroll = &set_scroll,
        .set_viewportAnchorX = &set_viewportAnchorX,
        .set_viewportAnchorY = &set_viewportAnchorY,
        .set_width = &set_width,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        VTTRegionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VTTRegionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try VTTRegionImpl.constructor(state);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return VTTRegionImpl.get_id(state);
    }

    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_id(state, value);
    }

    pub fn get_width(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTRegionImpl.get_width(state);
    }

    pub fn set_width(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_width(state, value);
    }

    pub fn get_lines(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VTTRegionImpl.get_lines(state);
    }

    pub fn set_lines(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_lines(state, value);
    }

    pub fn get_regionAnchorX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTRegionImpl.get_regionAnchorX(state);
    }

    pub fn set_regionAnchorX(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_regionAnchorX(state, value);
    }

    pub fn get_regionAnchorY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTRegionImpl.get_regionAnchorY(state);
    }

    pub fn set_regionAnchorY(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_regionAnchorY(state, value);
    }

    pub fn get_viewportAnchorX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTRegionImpl.get_viewportAnchorX(state);
    }

    pub fn set_viewportAnchorX(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_viewportAnchorX(state, value);
    }

    pub fn get_viewportAnchorY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTRegionImpl.get_viewportAnchorY(state);
    }

    pub fn set_viewportAnchorY(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_viewportAnchorY(state, value);
    }

    pub fn get_scroll(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTRegionImpl.get_scroll(state);
    }

    pub fn set_scroll(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTRegionImpl.set_scroll(state, value);
    }

};

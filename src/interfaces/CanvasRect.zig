//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasRectImpl = @import("../impls/CanvasRect.zig");

pub const CanvasRect = struct {
    pub const Meta = struct {
        pub const name = "CanvasRect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasRect, .{
        .deinit_fn = &deinit_wrapper,

        .call_clearRect = &call_clearRect,
        .call_fillRect = &call_fillRect,
        .call_strokeRect = &call_strokeRect,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasRectImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasRectImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasRectImpl.call_clearRect(state, x, y, w, h);
    }

    pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasRectImpl.call_fillRect(state, x, y, w, h);
    }

    pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasRectImpl.call_strokeRect(state, x, y, w, h);
    }

};

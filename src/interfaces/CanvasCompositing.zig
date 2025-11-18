//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasCompositingImpl = @import("../impls/CanvasCompositing.zig");

pub const CanvasCompositing = struct {
    pub const Meta = struct {
        pub const name = "CanvasCompositing";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            globalAlpha: f64 = undefined,
            globalCompositeOperation: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasCompositing, .{
        .deinit_fn = &deinit_wrapper,

        .get_globalAlpha = &get_globalAlpha,
        .get_globalCompositeOperation = &get_globalCompositeOperation,

        .set_globalAlpha = &set_globalAlpha,
        .set_globalCompositeOperation = &set_globalCompositeOperation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasCompositingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasCompositingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_globalAlpha(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasCompositingImpl.get_globalAlpha(state);
    }

    pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasCompositingImpl.set_globalAlpha(state, value);
    }

    pub fn get_globalCompositeOperation(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasCompositingImpl.get_globalCompositeOperation(state);
    }

    pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasCompositingImpl.set_globalCompositeOperation(state, value);
    }

};

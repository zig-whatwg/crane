//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasShadowStylesImpl = @import("../impls/CanvasShadowStyles.zig");

pub const CanvasShadowStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasShadowStyles";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            shadowOffsetX: f64 = undefined,
            shadowOffsetY: f64 = undefined,
            shadowBlur: f64 = undefined,
            shadowColor: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasShadowStyles, .{
        .deinit_fn = &deinit_wrapper,

        .get_shadowBlur = &get_shadowBlur,
        .get_shadowColor = &get_shadowColor,
        .get_shadowOffsetX = &get_shadowOffsetX,
        .get_shadowOffsetY = &get_shadowOffsetY,

        .set_shadowBlur = &set_shadowBlur,
        .set_shadowColor = &set_shadowColor,
        .set_shadowOffsetX = &set_shadowOffsetX,
        .set_shadowOffsetY = &set_shadowOffsetY,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasShadowStylesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasShadowStylesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_shadowOffsetX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasShadowStylesImpl.get_shadowOffsetX(state);
    }

    pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasShadowStylesImpl.set_shadowOffsetX(state, value);
    }

    pub fn get_shadowOffsetY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasShadowStylesImpl.get_shadowOffsetY(state);
    }

    pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasShadowStylesImpl.set_shadowOffsetY(state, value);
    }

    pub fn get_shadowBlur(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasShadowStylesImpl.get_shadowBlur(state);
    }

    pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasShadowStylesImpl.set_shadowBlur(state, value);
    }

    pub fn get_shadowColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasShadowStylesImpl.get_shadowColor(state);
    }

    pub fn set_shadowColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasShadowStylesImpl.set_shadowColor(state, value);
    }

};

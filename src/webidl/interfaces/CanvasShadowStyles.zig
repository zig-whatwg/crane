//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasShadowStylesImpl = @import("impls").CanvasShadowStyles;

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
        
        // Initialize the instance (Impl receives full instance)
        CanvasShadowStylesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasShadowStylesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasShadowStylesImpl.get_shadowOffsetX(instance);
    }

    pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowOffsetX(instance, value);
    }

    pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasShadowStylesImpl.get_shadowOffsetY(instance);
    }

    pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowOffsetY(instance, value);
    }

    pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasShadowStylesImpl.get_shadowBlur(instance);
    }

    pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowBlur(instance, value);
    }

    pub fn get_shadowColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasShadowStylesImpl.get_shadowColor(instance);
    }

    pub fn set_shadowColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasShadowStylesImpl.set_shadowColor(instance, value);
    }

};

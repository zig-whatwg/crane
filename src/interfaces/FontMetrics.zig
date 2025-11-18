//! Generated from: font-metrics-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontMetricsImpl = @import("../impls/FontMetrics.zig");

pub const FontMetrics = struct {
    pub const Meta = struct {
        pub const name = "FontMetrics";
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
            width: f64 = undefined,
            advances: FrozenArray<double> = undefined,
            boundingBoxLeft: f64 = undefined,
            boundingBoxRight: f64 = undefined,
            height: f64 = undefined,
            emHeightAscent: f64 = undefined,
            emHeightDescent: f64 = undefined,
            boundingBoxAscent: f64 = undefined,
            boundingBoxDescent: f64 = undefined,
            fontBoundingBoxAscent: f64 = undefined,
            fontBoundingBoxDescent: f64 = undefined,
            dominantBaseline: Baseline = undefined,
            baselines: FrozenArray<Baseline> = undefined,
            fonts: FrozenArray<Font> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FontMetrics, .{
        .deinit_fn = &deinit_wrapper,

        .get_advances = &get_advances,
        .get_baselines = &get_baselines,
        .get_boundingBoxAscent = &get_boundingBoxAscent,
        .get_boundingBoxDescent = &get_boundingBoxDescent,
        .get_boundingBoxLeft = &get_boundingBoxLeft,
        .get_boundingBoxRight = &get_boundingBoxRight,
        .get_dominantBaseline = &get_dominantBaseline,
        .get_emHeightAscent = &get_emHeightAscent,
        .get_emHeightDescent = &get_emHeightDescent,
        .get_fontBoundingBoxAscent = &get_fontBoundingBoxAscent,
        .get_fontBoundingBoxDescent = &get_fontBoundingBoxDescent,
        .get_fonts = &get_fonts,
        .get_height = &get_height,
        .get_width = &get_width,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FontMetricsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FontMetricsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_width(state);
    }

    pub fn get_advances(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontMetricsImpl.get_advances(state);
    }

    pub fn get_boundingBoxLeft(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_boundingBoxLeft(state);
    }

    pub fn get_boundingBoxRight(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_boundingBoxRight(state);
    }

    pub fn get_height(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_height(state);
    }

    pub fn get_emHeightAscent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_emHeightAscent(state);
    }

    pub fn get_emHeightDescent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_emHeightDescent(state);
    }

    pub fn get_boundingBoxAscent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_boundingBoxAscent(state);
    }

    pub fn get_boundingBoxDescent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_boundingBoxDescent(state);
    }

    pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_fontBoundingBoxAscent(state);
    }

    pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return FontMetricsImpl.get_fontBoundingBoxDescent(state);
    }

    pub fn get_dominantBaseline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontMetricsImpl.get_dominantBaseline(state);
    }

    pub fn get_baselines(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontMetricsImpl.get_baselines(state);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FontMetricsImpl.get_fonts(state);
    }

};

//! Generated from: font-metrics-api.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FontMetricsImpl = @import("impls").FontMetrics;
const Font = @import("interfaces").Font;
const Baseline = @import("interfaces").Baseline;

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
            advances: runtime.FrozenArray(f64) = undefined,
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
            baselines: runtime.FrozenArray(Baseline) = undefined,
            fonts: runtime.FrozenArray(Font) = undefined,
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
        return FontMetricsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontMetricsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_width(instance);
    }

    pub fn get_advances(instance: *runtime.Instance) anyerror!anyopaque {
        return try FontMetricsImpl.get_advances(instance);
    }

    pub fn get_boundingBoxLeft(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxLeft(instance);
    }

    pub fn get_boundingBoxRight(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxRight(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_height(instance);
    }

    pub fn get_emHeightAscent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_emHeightAscent(instance);
    }

    pub fn get_emHeightDescent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_emHeightDescent(instance);
    }

    pub fn get_boundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxAscent(instance);
    }

    pub fn get_boundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_boundingBoxDescent(instance);
    }

    pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_fontBoundingBoxAscent(instance);
    }

    pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_fontBoundingBoxDescent(instance);
    }

    pub fn get_dominantBaseline(instance: *runtime.Instance) anyerror!Baseline {
        return try FontMetricsImpl.get_dominantBaseline(instance);
    }

    pub fn get_baselines(instance: *runtime.Instance) anyerror!anyopaque {
        return try FontMetricsImpl.get_baselines(instance);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!anyopaque {
        return try FontMetricsImpl.get_fonts(instance);
    }

};

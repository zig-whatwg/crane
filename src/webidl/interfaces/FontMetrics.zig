//! Generated from: font-metrics-api.idl
//! Generated at: 2025-11-23T19:47:41Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "advances", "get_advances", null },
            .{ "boundingBoxLeft", "get_boundingBoxLeft", null },
            .{ "boundingBoxRight", "get_boundingBoxRight", null },
            .{ "height", "get_height", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "boundingBoxAscent", "get_boundingBoxAscent", null },
            .{ "boundingBoxDescent", "get_boundingBoxDescent", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "dominantBaseline", "get_dominantBaseline", null },
            .{ "baselines", "get_baselines", null },
            .{ "fonts", "get_fonts", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "advances", "get_advances", null },
            .{ "boundingBoxLeft", "get_boundingBoxLeft", null },
            .{ "boundingBoxRight", "get_boundingBoxRight", null },
            .{ "height", "get_height", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "boundingBoxAscent", "get_boundingBoxAscent", null },
            .{ "boundingBoxDescent", "get_boundingBoxDescent", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "dominantBaseline", "get_dominantBaseline", null },
            .{ "baselines", "get_baselines", null },
            .{ "fonts", "get_fonts", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
            dominantBaseline: *runtime.Instance = undefined,
            baselines: runtime.FrozenArray(Baseline) = undefined,
            fonts: runtime.FrozenArray(Font) = undefined,
            _internal: ?*FontMetricsImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FontMetricsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FontMetricsImpl.deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try FontMetricsImpl.get_width(instance);
    }

    pub fn get_advances(instance: *runtime.Instance) anyerror!*const anyopaque {
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

    pub fn get_dominantBaseline(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try FontMetricsImpl.get_dominantBaseline(instance);
    }

    pub fn get_baselines(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FontMetricsImpl.get_baselines(instance);
    }

    pub fn get_fonts(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FontMetricsImpl.get_fonts(instance);
    }

};

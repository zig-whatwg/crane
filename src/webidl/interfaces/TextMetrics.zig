//! Generated from: html.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextMetricsImpl = @import("impls").TextMetrics;

pub const TextMetrics = struct {
    pub const Meta = struct {
        pub const name = "TextMetrics";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "actualBoundingBoxLeft", "get_actualBoundingBoxLeft", null },
            .{ "actualBoundingBoxRight", "get_actualBoundingBoxRight", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "actualBoundingBoxAscent", "get_actualBoundingBoxAscent", null },
            .{ "actualBoundingBoxDescent", "get_actualBoundingBoxDescent", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "hangingBaseline", "get_hangingBaseline", null },
            .{ "alphabeticBaseline", "get_alphabeticBaseline", null },
            .{ "ideographicBaseline", "get_ideographicBaseline", null },
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
            .{ "actualBoundingBoxLeft", "get_actualBoundingBoxLeft", null },
            .{ "actualBoundingBoxRight", "get_actualBoundingBoxRight", null },
            .{ "fontBoundingBoxAscent", "get_fontBoundingBoxAscent", null },
            .{ "fontBoundingBoxDescent", "get_fontBoundingBoxDescent", null },
            .{ "actualBoundingBoxAscent", "get_actualBoundingBoxAscent", null },
            .{ "actualBoundingBoxDescent", "get_actualBoundingBoxDescent", null },
            .{ "emHeightAscent", "get_emHeightAscent", null },
            .{ "emHeightDescent", "get_emHeightDescent", null },
            .{ "hangingBaseline", "get_hangingBaseline", null },
            .{ "alphabeticBaseline", "get_alphabeticBaseline", null },
            .{ "ideographicBaseline", "get_ideographicBaseline", null },
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
            actualBoundingBoxLeft: f64 = undefined,
            actualBoundingBoxRight: f64 = undefined,
            fontBoundingBoxAscent: f64 = undefined,
            fontBoundingBoxDescent: f64 = undefined,
            actualBoundingBoxAscent: f64 = undefined,
            actualBoundingBoxDescent: f64 = undefined,
            emHeightAscent: f64 = undefined,
            emHeightDescent: f64 = undefined,
            hangingBaseline: f64 = undefined,
            alphabeticBaseline: f64 = undefined,
            ideographicBaseline: f64 = undefined,
        },
    );

    const delegates = .{

        .get_actualBoundingBoxAscent = &get_actualBoundingBoxAscent,
        .get_actualBoundingBoxDescent = &get_actualBoundingBoxDescent,
        .get_actualBoundingBoxLeft = &get_actualBoundingBoxLeft,
        .get_actualBoundingBoxRight = &get_actualBoundingBoxRight,
        .get_alphabeticBaseline = &get_alphabeticBaseline,
        .get_emHeightAscent = &get_emHeightAscent,
        .get_emHeightDescent = &get_emHeightDescent,
        .get_fontBoundingBoxAscent = &get_fontBoundingBoxAscent,
        .get_fontBoundingBoxDescent = &get_fontBoundingBoxDescent,
        .get_hangingBaseline = &get_hangingBaseline,
        .get_ideographicBaseline = &get_ideographicBaseline,
        .get_width = &get_width,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextMetricsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextMetricsImpl.deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_width(instance);
    }

    pub fn get_actualBoundingBoxLeft(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxLeft(instance);
    }

    pub fn get_actualBoundingBoxRight(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxRight(instance);
    }

    pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_fontBoundingBoxAscent(instance);
    }

    pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_fontBoundingBoxDescent(instance);
    }

    pub fn get_actualBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxAscent(instance);
    }

    pub fn get_actualBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_actualBoundingBoxDescent(instance);
    }

    pub fn get_emHeightAscent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_emHeightAscent(instance);
    }

    pub fn get_emHeightDescent(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_emHeightDescent(instance);
    }

    pub fn get_hangingBaseline(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_hangingBaseline(instance);
    }

    pub fn get_alphabeticBaseline(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_alphabeticBaseline(instance);
    }

    pub fn get_ideographicBaseline(instance: *runtime.Instance) anyerror!f64 {
        return try TextMetricsImpl.get_ideographicBaseline(instance);
    }

};

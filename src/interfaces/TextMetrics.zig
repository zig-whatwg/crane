//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextMetricsImpl = @import("../impls/TextMetrics.zig");

pub const TextMetrics = struct {
    pub const Meta = struct {
        pub const name = "TextMetrics";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
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
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextMetrics, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TextMetricsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextMetricsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_width(state);
    }

    pub fn get_actualBoundingBoxLeft(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_actualBoundingBoxLeft(state);
    }

    pub fn get_actualBoundingBoxRight(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_actualBoundingBoxRight(state);
    }

    pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_fontBoundingBoxAscent(state);
    }

    pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_fontBoundingBoxDescent(state);
    }

    pub fn get_actualBoundingBoxAscent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_actualBoundingBoxAscent(state);
    }

    pub fn get_actualBoundingBoxDescent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_actualBoundingBoxDescent(state);
    }

    pub fn get_emHeightAscent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_emHeightAscent(state);
    }

    pub fn get_emHeightDescent(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_emHeightDescent(state);
    }

    pub fn get_hangingBaseline(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_hangingBaseline(state);
    }

    pub fn get_alphabeticBaseline(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_alphabeticBaseline(state);
    }

    pub fn get_ideographicBaseline(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextMetricsImpl.get_ideographicBaseline(state);
    }

};

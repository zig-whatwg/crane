//! Generated from: webgl1.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLShaderPrecisionFormatImpl = @import("../impls/WebGLShaderPrecisionFormat.zig");

pub const WebGLShaderPrecisionFormat = struct {
    pub const Meta = struct {
        pub const name = "WebGLShaderPrecisionFormat";
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
            rangeMin: GLint = undefined,
            rangeMax: GLint = undefined,
            precision: GLint = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebGLShaderPrecisionFormat, .{
        .deinit_fn = &deinit_wrapper,

        .get_precision = &get_precision,
        .get_rangeMax = &get_rangeMax,
        .get_rangeMin = &get_rangeMin,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WebGLShaderPrecisionFormatImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebGLShaderPrecisionFormatImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_rangeMin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGLShaderPrecisionFormatImpl.get_rangeMin(state);
    }

    pub fn get_rangeMax(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGLShaderPrecisionFormatImpl.get_rangeMax(state);
    }

    pub fn get_precision(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebGLShaderPrecisionFormatImpl.get_precision(state);
    }

};

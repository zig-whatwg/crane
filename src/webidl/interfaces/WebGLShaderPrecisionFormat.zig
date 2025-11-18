//! Generated from: webgl1.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLShaderPrecisionFormatImpl = @import("impls").WebGLShaderPrecisionFormat;
const GLint = @import("typedefs").GLint;

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
        
        // Initialize the instance (Impl receives full instance)
        WebGLShaderPrecisionFormatImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLShaderPrecisionFormatImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_rangeMin(instance: *runtime.Instance) anyerror!GLint {
        return try WebGLShaderPrecisionFormatImpl.get_rangeMin(instance);
    }

    pub fn get_rangeMax(instance: *runtime.Instance) anyerror!GLint {
        return try WebGLShaderPrecisionFormatImpl.get_rangeMax(instance);
    }

    pub fn get_precision(instance: *runtime.Instance) anyerror!GLint {
        return try WebGLShaderPrecisionFormatImpl.get_precision(instance);
    }

};

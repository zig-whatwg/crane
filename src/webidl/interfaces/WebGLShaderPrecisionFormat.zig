//! Generated from: webgl1.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebGLShaderPrecisionFormatImpl = @import("impls").WebGLShaderPrecisionFormat;
const mixins = @import("mixins");
const GLint = @import("typedefs").GLint;

pub const WebGLShaderPrecisionFormat = struct {
    pub const Meta = struct {
        pub const name = "WebGLShaderPrecisionFormat";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "rangeMin", "get_rangeMin", null },
            .{ "rangeMax", "get_rangeMax", null },
            .{ "precision", "get_precision", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "rangeMin", "get_rangeMin", null },
            .{ "rangeMax", "get_rangeMax", null },
            .{ "precision", "get_precision", null },
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
            rangeMin: GLint = undefined,
            rangeMax: GLint = undefined,
            precision: GLint = undefined,
            _internal: ?*WebGLShaderPrecisionFormatImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_precision = &get_precision,
        .get_rangeMax = &get_rangeMax,
        .get_rangeMin = &get_rangeMin,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebGLShaderPrecisionFormatImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLShaderPrecisionFormatImpl.deinit(instance);
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

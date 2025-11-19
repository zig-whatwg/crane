//! Generated from: WEBGL_debug_shaders.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_debug_shadersImpl = @import("impls").WEBGL_debug_shaders;
const DOMString = @import("typedefs").DOMString;
const WebGLShader = @import("interfaces").WebGLShader;

pub const WEBGL_debug_shaders = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_debug_shaders";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WEBGL_debug_shaders, .{
        .deinit_fn = &deinit_wrapper,

        .call_getTranslatedShaderSource = &call_getTranslatedShaderSource,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WEBGL_debug_shadersImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_debug_shadersImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getTranslatedShaderSource(instance: *runtime.Instance, shader: WebGLShader) anyerror!DOMString {
        
        return try WEBGL_debug_shadersImpl.call_getTranslatedShaderSource(instance, shader);
    }

};

//! Generated from: WEBGL_debug_shaders.idl
//! Generated at: 2025-11-23T16:59:12Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getTranslatedShaderSource", "call_getTranslatedShaderSource", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTranslatedShaderSource",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_getTranslatedShaderSource = &call_getTranslatedShaderSource,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_debug_shadersImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_debug_shadersImpl.deinit(instance);
    }

    pub fn call_getTranslatedShaderSource(instance: *runtime.Instance, shader: WebGLShader) anyerror!DOMString {
        
        return try WEBGL_debug_shadersImpl.call_getTranslatedShaderSource(instance, shader);
    }

};

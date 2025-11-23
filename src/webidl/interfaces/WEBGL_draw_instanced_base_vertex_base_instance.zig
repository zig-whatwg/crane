//! Generated from: WEBGL_draw_instanced_base_vertex_base_instance.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_draw_instanced_base_vertex_base_instanceImpl = @import("impls").WEBGL_draw_instanced_base_vertex_base_instance;
const GLenum = @import("typedefs").GLenum;
const GLint = @import("typedefs").GLint;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const GLuint = @import("typedefs").GLuint;

pub const WEBGL_draw_instanced_base_vertex_base_instance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_draw_instanced_base_vertex_base_instance";
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
            .{ "drawArraysInstancedBaseInstanceWEBGL", "call_drawArraysInstancedBaseInstanceWEBGL", 5 },
            .{ "drawElementsInstancedBaseVertexBaseInstanceWEBGL", "call_drawElementsInstancedBaseVertexBaseInstanceWEBGL", 7 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawArraysInstancedBaseInstanceWEBGL",
            "drawElementsInstancedBaseVertexBaseInstanceWEBGL",
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

        .call_drawArraysInstancedBaseInstanceWEBGL = &call_drawArraysInstancedBaseInstanceWEBGL,
        .call_drawElementsInstancedBaseVertexBaseInstanceWEBGL = &call_drawElementsInstancedBaseVertexBaseInstanceWEBGL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_draw_instanced_base_vertex_base_instanceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_draw_instanced_base_vertex_base_instanceImpl.deinit(instance);
    }

    pub fn call_drawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, instanceCount: GLsizei, baseInstance: GLuint) anyerror!void {
        
        return try WEBGL_draw_instanced_base_vertex_base_instanceImpl.call_drawArraysInstancedBaseInstanceWEBGL(instance, mode, first, count, instanceCount, baseInstance);
    }

    pub fn call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, count: GLsizei, @"type": GLenum, offset: GLintptr, instanceCount: GLsizei, baseVertex: GLint, baseInstance: GLuint) anyerror!void {
        
        return try WEBGL_draw_instanced_base_vertex_base_instanceImpl.call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance, mode, count, @"type", offset, instanceCount, baseVertex, baseInstance);
    }

};

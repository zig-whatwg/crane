//! Generated from: WEBGL_draw_instanced_base_vertex_base_instance.idl
//! Generated at: 2025-11-18T18:28:12Z
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

    pub const vtable = runtime.buildVTable(WEBGL_draw_instanced_base_vertex_base_instance, .{
        .deinit_fn = &deinit_wrapper,

        .call_drawArraysInstancedBaseInstanceWEBGL = &call_drawArraysInstancedBaseInstanceWEBGL,
        .call_drawElementsInstancedBaseVertexBaseInstanceWEBGL = &call_drawElementsInstancedBaseVertexBaseInstanceWEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_draw_instanced_base_vertex_base_instanceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_draw_instanced_base_vertex_base_instanceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, instanceCount: GLsizei, baseInstance: GLuint) anyerror!void {
        
        return try WEBGL_draw_instanced_base_vertex_base_instanceImpl.call_drawArraysInstancedBaseInstanceWEBGL(instance, mode, first, count, instanceCount, baseInstance);
    }

    pub fn call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, count: GLsizei, type_: GLenum, offset: GLintptr, instanceCount: GLsizei, baseVertex: GLint, baseInstance: GLuint) anyerror!void {
        
        return try WEBGL_draw_instanced_base_vertex_base_instanceImpl.call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance, mode, count, type_, offset, instanceCount, baseVertex, baseInstance);
    }

};

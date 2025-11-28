//! Generated from: WEBGL_multi_draw_instanced_base_vertex_base_instance.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl = @import("impls").WEBGL_multi_draw_instanced_base_vertex_base_instance;
const GLenum = @import("typedefs").GLenum;
const GLsizei = @import("typedefs").GLsizei;
const sequence = @import("interfaces").sequence;
const GLint = @import("typedefs").GLint;
const GLuint = @import("typedefs").GLuint;

pub const WEBGL_multi_draw_instanced_base_vertex_base_instance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_multi_draw_instanced_base_vertex_base_instance";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "multiDrawArraysInstancedBaseInstanceWEBGL", "call_multiDrawArraysInstancedBaseInstanceWEBGL", 10 },
            .{ "multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL", "call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL", 13 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "multiDrawArraysInstancedBaseInstanceWEBGL",
            "multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL",
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
        struct {
            _internal: ?*WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_multiDrawArraysInstancedBaseInstanceWEBGL = &call_multiDrawArraysInstancedBaseInstanceWEBGL,
        .call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL = &call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.deinit(instance);
    }

    pub fn call_multiDrawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: *const anyopaque, firstsOffset: u64, countsList: *const anyopaque, countsOffset: u64, instanceCountsList: *const anyopaque, instanceCountsOffset: u64, baseInstancesList: *const anyopaque, baseInstancesOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.call_multiDrawArraysInstancedBaseInstanceWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, instanceCountsList, instanceCountsOffset, baseInstancesList, baseInstancesOffset, drawcount);
    }

    pub fn call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: *const anyopaque, countsOffset: u64, @"type": GLenum, offsetsList: *const anyopaque, offsetsOffset: u64, instanceCountsList: *const anyopaque, instanceCountsOffset: u64, baseVerticesList: *const anyopaque, baseVerticesOffset: u64, baseInstancesList: *const anyopaque, baseInstancesOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance, mode, countsList, countsOffset, @"type", offsetsList, offsetsOffset, instanceCountsList, instanceCountsOffset, baseVerticesList, baseVerticesOffset, baseInstancesList, baseInstancesOffset, drawcount);
    }

};

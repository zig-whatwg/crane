//! Generated from: WEBGL_provoking_vertex.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_provoking_vertexImpl = @import("impls").WEBGL_provoking_vertex;
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_provoking_vertex = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_provoking_vertex";
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
            .{ "provokingVertexWEBGL", "call_provokingVertexWEBGL", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "FIRST_VERTEX_CONVENTION_WEBGL", "get_FIRST_VERTEX_CONVENTION_WEBGL" },
            .{ "LAST_VERTEX_CONVENTION_WEBGL", "get_LAST_VERTEX_CONVENTION_WEBGL" },
            .{ "PROVOKING_VERTEX_WEBGL", "get_PROVOKING_VERTEX_WEBGL" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "provokingVertexWEBGL",
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

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum FIRST_VERTEX_CONVENTION_WEBGL = 36429;
    pub fn get_FIRST_VERTEX_CONVENTION_WEBGL() GLenum {
        return 36429;
    }

    /// WebIDL constant: const GLenum LAST_VERTEX_CONVENTION_WEBGL = 36430;
    pub fn get_LAST_VERTEX_CONVENTION_WEBGL() GLenum {
        return 36430;
    }

    /// WebIDL constant: const GLenum PROVOKING_VERTEX_WEBGL = 36431;
    pub fn get_PROVOKING_VERTEX_WEBGL() GLenum {
        return 36431;
    }

    const delegates = .{

        .get_FIRST_VERTEX_CONVENTION_WEBGL = &get_FIRST_VERTEX_CONVENTION_WEBGL,
        .get_LAST_VERTEX_CONVENTION_WEBGL = &get_LAST_VERTEX_CONVENTION_WEBGL,
        .get_PROVOKING_VERTEX_WEBGL = &get_PROVOKING_VERTEX_WEBGL,

        .call_provokingVertexWEBGL = &call_provokingVertexWEBGL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_provoking_vertexImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_provoking_vertexImpl.deinit(instance);
    }

    pub fn call_provokingVertexWEBGL(instance: *runtime.Instance, provokeMode: GLenum) anyerror!void {
        
        return try WEBGL_provoking_vertexImpl.call_provokingVertexWEBGL(instance, provokeMode);
    }

};

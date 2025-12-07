//! Generated from: ANGLE_instanced_arrays.idl
//! Generated at: 2025-12-07T19:33:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ANGLE_instanced_arraysImpl = @import("impls").ANGLE_instanced_arrays;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;
const GLint = @import("typedefs").GLint;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const GLuint = @import("typedefs").GLuint;

pub const ANGLE_instanced_arrays = struct {
    pub const Meta = struct {
        pub const name = "ANGLE_instanced_arrays";
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
            .{ "drawArraysInstancedANGLE", "call_drawArraysInstancedANGLE", 4 },
            .{ "drawElementsInstancedANGLE", "call_drawElementsInstancedANGLE", 5 },
            .{ "vertexAttribDivisorANGLE", "call_vertexAttribDivisorANGLE", 2 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE", "get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "drawArraysInstancedANGLE",
            "drawElementsInstancedANGLE",
            "vertexAttribDivisorANGLE",
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
            _internal: ?*ANGLE_instanced_arraysImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE = 35070;
    pub fn get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE() GLenum {
        return 35070;
    }

    const delegates = .{

        .get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE = &get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE,

        .call_drawArraysInstancedANGLE = &call_drawArraysInstancedANGLE,
        .call_drawElementsInstancedANGLE = &call_drawElementsInstancedANGLE,
        .call_vertexAttribDivisorANGLE = &call_vertexAttribDivisorANGLE,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ANGLE_instanced_arraysImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ANGLE_instanced_arraysImpl.deinit(instance);
    }

    pub fn call_drawArraysInstancedANGLE(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, primcount: GLsizei) anyerror!void {
        
        return try ANGLE_instanced_arraysImpl.call_drawArraysInstancedANGLE(instance, mode, first, count, primcount);
    }

    pub fn call_vertexAttribDivisorANGLE(instance: *runtime.Instance, index: GLuint, divisor: GLuint) anyerror!void {
        
        return try ANGLE_instanced_arraysImpl.call_vertexAttribDivisorANGLE(instance, index, divisor);
    }

    pub fn call_drawElementsInstancedANGLE(instance: *runtime.Instance, mode: GLenum, count: GLsizei, @"type": GLenum, offset: GLintptr, primcount: GLsizei) anyerror!void {
        
        return try ANGLE_instanced_arraysImpl.call_drawElementsInstancedANGLE(instance, mode, count, @"type", offset, primcount);
    }

};

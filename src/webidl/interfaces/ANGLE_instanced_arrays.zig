//! Generated from: ANGLE_instanced_arrays.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ANGLE_instanced_arraysImpl = @import("impls").ANGLE_instanced_arrays;
const GLenum = @import("typedefs").GLenum;
const GLint = @import("typedefs").GLint;
const GLintptr = @import("typedefs").GLintptr;
const GLsizei = @import("typedefs").GLsizei;
const GLuint = @import("typedefs").GLuint;

pub const ANGLE_instanced_arrays = struct {
    pub const Meta = struct {
        pub const name = "ANGLE_instanced_arrays";
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

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE = 35070;
    pub fn get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE() GLenum {
        return 35070;
    }

    pub const vtable = runtime.buildVTable(ANGLE_instanced_arrays, .{
        .deinit_fn = &deinit_wrapper,

        .get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE = &get_VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE,

        .call_drawArraysInstancedANGLE = &call_drawArraysInstancedANGLE,
        .call_drawElementsInstancedANGLE = &call_drawElementsInstancedANGLE,
        .call_vertexAttribDivisorANGLE = &call_vertexAttribDivisorANGLE,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ANGLE_instanced_arraysImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ANGLE_instanced_arraysImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawArraysInstancedANGLE(instance: *runtime.Instance, mode: GLenum, first: GLint, count: GLsizei, primcount: GLsizei) anyerror!void {
        
        return try ANGLE_instanced_arraysImpl.call_drawArraysInstancedANGLE(instance, mode, first, count, primcount);
    }

    pub fn call_vertexAttribDivisorANGLE(instance: *runtime.Instance, index: GLuint, divisor: GLuint) anyerror!void {
        
        return try ANGLE_instanced_arraysImpl.call_vertexAttribDivisorANGLE(instance, index, divisor);
    }

    pub fn call_drawElementsInstancedANGLE(instance: *runtime.Instance, mode: GLenum, count: GLsizei, type_: GLenum, offset: GLintptr, primcount: GLsizei) anyerror!void {
        
        return try ANGLE_instanced_arraysImpl.call_drawElementsInstancedANGLE(instance, mode, count, type_, offset, primcount);
    }

};

//! Generated from: ANGLE_instanced_arrays.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ANGLE_instanced_arraysImpl = @import("../impls/ANGLE_instanced_arrays.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ANGLE_instanced_arraysImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ANGLE_instanced_arraysImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawArraysInstancedANGLE(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque, primcount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ANGLE_instanced_arraysImpl.call_drawArraysInstancedANGLE(state, mode, first, count, primcount);
    }

    pub fn call_vertexAttribDivisorANGLE(instance: *runtime.Instance, index: anyopaque, divisor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ANGLE_instanced_arraysImpl.call_vertexAttribDivisorANGLE(state, index, divisor);
    }

    pub fn call_drawElementsInstancedANGLE(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type_: anyopaque, offset: anyopaque, primcount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ANGLE_instanced_arraysImpl.call_drawElementsInstancedANGLE(state, mode, count, type_, offset, primcount);
    }

};

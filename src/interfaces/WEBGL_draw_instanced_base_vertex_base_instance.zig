//! Generated from: WEBGL_draw_instanced_base_vertex_base_instance.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_draw_instanced_base_vertex_base_instanceImpl = @import("../impls/WEBGL_draw_instanced_base_vertex_base_instance.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_draw_instanced_base_vertex_base_instanceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_draw_instanced_base_vertex_base_instanceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_drawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: anyopaque, first: anyopaque, count: anyopaque, instanceCount: anyopaque, baseInstance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_draw_instanced_base_vertex_base_instanceImpl.call_drawArraysInstancedBaseInstanceWEBGL(state, mode, first, count, instanceCount, baseInstance);
    }

    pub fn call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: anyopaque, count: anyopaque, type_: anyopaque, offset: anyopaque, instanceCount: anyopaque, baseVertex: anyopaque, baseInstance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_draw_instanced_base_vertex_base_instanceImpl.call_drawElementsInstancedBaseVertexBaseInstanceWEBGL(state, mode, count, type_, offset, instanceCount, baseVertex, baseInstance);
    }

};

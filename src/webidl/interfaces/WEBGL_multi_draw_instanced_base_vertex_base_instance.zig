//! Generated from: WEBGL_multi_draw_instanced_base_vertex_base_instance.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl = @import("impls").WEBGL_multi_draw_instanced_base_vertex_base_instance;
const GLenum = @import("typedefs").GLenum;
const (Uint32Array or sequence) = @import("interfaces").(Uint32Array or sequence);
const (Int32Array or sequence) = @import("interfaces").(Int32Array or sequence);
const GLsizei = @import("typedefs").GLsizei;

pub const WEBGL_multi_draw_instanced_base_vertex_base_instance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_multi_draw_instanced_base_vertex_base_instance";
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

    pub const vtable = runtime.buildVTable(WEBGL_multi_draw_instanced_base_vertex_base_instance, .{
        .deinit_fn = &deinit_wrapper,

        .call_multiDrawArraysInstancedBaseInstanceWEBGL = &call_multiDrawArraysInstancedBaseInstanceWEBGL,
        .call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL = &call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_multiDrawArraysInstancedBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, baseInstancesList: anyopaque, baseInstancesOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.call_multiDrawArraysInstancedBaseInstanceWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, instanceCountsList, instanceCountsOffset, baseInstancesList, baseInstancesOffset, drawcount);
    }

    pub fn call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: anyopaque, countsOffset: u64, type_: GLenum, offsetsList: anyopaque, offsetsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, baseVerticesList: anyopaque, baseVerticesOffset: u64, baseInstancesList: anyopaque, baseInstancesOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_draw_instanced_base_vertex_base_instanceImpl.call_multiDrawElementsInstancedBaseVertexBaseInstanceWEBGL(instance, mode, countsList, countsOffset, type_, offsetsList, offsetsOffset, instanceCountsList, instanceCountsOffset, baseVerticesList, baseVerticesOffset, baseInstancesList, baseInstancesOffset, drawcount);
    }

};

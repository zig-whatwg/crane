//! Generated from: WEBGL_provoking_vertex.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_provoking_vertexImpl = @import("impls").WEBGL_provoking_vertex;
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_provoking_vertex = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_provoking_vertex";
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

    pub const vtable = runtime.buildVTable(WEBGL_provoking_vertex, .{
        .deinit_fn = &deinit_wrapper,

        .get_FIRST_VERTEX_CONVENTION_WEBGL = &get_FIRST_VERTEX_CONVENTION_WEBGL,
        .get_LAST_VERTEX_CONVENTION_WEBGL = &get_LAST_VERTEX_CONVENTION_WEBGL,
        .get_PROVOKING_VERTEX_WEBGL = &get_PROVOKING_VERTEX_WEBGL,

        .call_provokingVertexWEBGL = &call_provokingVertexWEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_provoking_vertexImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_provoking_vertexImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_provokingVertexWEBGL(instance: *runtime.Instance, provokeMode: GLenum) anyerror!void {
        
        return try WEBGL_provoking_vertexImpl.call_provokingVertexWEBGL(instance, provokeMode);
    }

};

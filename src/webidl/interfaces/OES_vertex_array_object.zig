//! Generated from: OES_vertex_array_object.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OES_vertex_array_objectImpl = @import("impls").OES_vertex_array_object;
const WebGLVertexArrayObjectOES = @import("interfaces").WebGLVertexArrayObjectOES;
const GLboolean = @import("typedefs").GLboolean;

pub const OES_vertex_array_object = struct {
    pub const Meta = struct {
        pub const name = "OES_vertex_array_object";
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

    /// WebIDL constant: const GLenum VERTEX_ARRAY_BINDING_OES = 34229;
    pub fn get_VERTEX_ARRAY_BINDING_OES() GLenum {
        return 34229;
    }

    pub const vtable = runtime.buildVTable(OES_vertex_array_object, .{
        .deinit_fn = &deinit_wrapper,

        .get_VERTEX_ARRAY_BINDING_OES = &get_VERTEX_ARRAY_BINDING_OES,

        .call_bindVertexArrayOES = &call_bindVertexArrayOES,
        .call_createVertexArrayOES = &call_createVertexArrayOES,
        .call_deleteVertexArrayOES = &call_deleteVertexArrayOES,
        .call_isVertexArrayOES = &call_isVertexArrayOES,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        OES_vertex_array_objectImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OES_vertex_array_objectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_bindVertexArrayOES(instance: *runtime.Instance, arrayObject: anyopaque) anyerror!void {
        
        return try OES_vertex_array_objectImpl.call_bindVertexArrayOES(instance, arrayObject);
    }

    pub fn call_createVertexArrayOES(instance: *runtime.Instance) anyerror!WebGLVertexArrayObjectOES {
        return try OES_vertex_array_objectImpl.call_createVertexArrayOES(instance);
    }

    pub fn call_deleteVertexArrayOES(instance: *runtime.Instance, arrayObject: anyopaque) anyerror!void {
        
        return try OES_vertex_array_objectImpl.call_deleteVertexArrayOES(instance, arrayObject);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isVertexArrayOES(instance: *runtime.Instance, arrayObject: anyopaque) anyerror!GLboolean {
        
        return try OES_vertex_array_objectImpl.call_isVertexArrayOES(instance, arrayObject);
    }

};

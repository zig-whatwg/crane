//! Generated from: OES_vertex_array_object.idl
//! Generated at: 2025-11-23T19:17:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OES_vertex_array_objectImpl = @import("impls").OES_vertex_array_object;
const GLenum = @import("typedefs").GLenum;
const WebGLVertexArrayObjectOES = @import("interfaces").WebGLVertexArrayObjectOES;
const GLboolean = @import("typedefs").GLboolean;

pub const OES_vertex_array_object = struct {
    pub const Meta = struct {
        pub const name = "OES_vertex_array_object";
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
            .{ "createVertexArrayOES", "call_createVertexArrayOES", 0 },
            .{ "deleteVertexArrayOES", "call_deleteVertexArrayOES", 1 },
            .{ "isVertexArrayOES", "call_isVertexArrayOES", 1 },
            .{ "bindVertexArrayOES", "call_bindVertexArrayOES", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "VERTEX_ARRAY_BINDING_OES", "get_VERTEX_ARRAY_BINDING_OES" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createVertexArrayOES",
            "deleteVertexArrayOES",
            "isVertexArrayOES",
            "bindVertexArrayOES",
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

    /// WebIDL constant: const GLenum VERTEX_ARRAY_BINDING_OES = 34229;
    pub fn get_VERTEX_ARRAY_BINDING_OES() GLenum {
        return 34229;
    }

    const delegates = .{

        .get_VERTEX_ARRAY_BINDING_OES = &get_VERTEX_ARRAY_BINDING_OES,

        .call_bindVertexArrayOES = &call_bindVertexArrayOES,
        .call_createVertexArrayOES = &call_createVertexArrayOES,
        .call_deleteVertexArrayOES = &call_deleteVertexArrayOES,
        .call_isVertexArrayOES = &call_isVertexArrayOES,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OES_vertex_array_objectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OES_vertex_array_objectImpl.deinit(instance);
    }

    pub fn call_bindVertexArrayOES(instance: *runtime.Instance, arrayObject: *runtime.Instance) anyerror!void {
        
        return try OES_vertex_array_objectImpl.call_bindVertexArrayOES(instance, arrayObject);
    }

    pub fn call_createVertexArrayOES(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try OES_vertex_array_objectImpl.call_createVertexArrayOES(instance);
    }

    pub fn call_deleteVertexArrayOES(instance: *runtime.Instance, arrayObject: *runtime.Instance) anyerror!void {
        
        return try OES_vertex_array_objectImpl.call_deleteVertexArrayOES(instance, arrayObject);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isVertexArrayOES(instance: *runtime.Instance, arrayObject: *runtime.Instance) anyerror!GLboolean {
        
        return try OES_vertex_array_objectImpl.call_isVertexArrayOES(instance, arrayObject);
    }

};

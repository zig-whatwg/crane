//! Generated from: real-world-meshing.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRMeshImpl = @import("impls").XRMesh;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;
const XRSpace = @import("interfaces").XRSpace;

pub const XRMesh = struct {
    pub const Meta = struct {
        pub const name = "XRMesh";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "meshSpace", "get_meshSpace", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
            .{ "lastChangedTime", "get_lastChangedTime", null },
            .{ "semanticLabel", "get_semanticLabel", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "meshSpace", "get_meshSpace", null },
            .{ "vertices", "get_vertices", null },
            .{ "indices", "get_indices", null },
            .{ "lastChangedTime", "get_lastChangedTime", null },
            .{ "semanticLabel", "get_semanticLabel", null },
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
            meshSpace: *runtime.Instance = undefined,
            vertices: runtime.FrozenArray(runtime.Float32Array) = undefined,
            indices: runtime.Uint32Array = undefined,
            lastChangedTime: DOMHighResTimeStamp = undefined,
            semanticLabel: ?runtime.DOMString = null,
            cached_meshSpace: ?*runtime.Instance = null,
            _internal: ?*XRMeshImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_indices = &get_indices,
        .get_lastChangedTime = &get_lastChangedTime,
        .get_meshSpace = &get_meshSpace,
        .get_semanticLabel = &get_semanticLabel,
        .get_vertices = &get_vertices,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRMeshImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRMeshImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_meshSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_meshSpace) |cached| {
            return cached;
        }
        const value = try XRMeshImpl.get_meshSpace(instance);
        state.own.cached_meshSpace = value;
        return value;
    }

    pub fn get_vertices(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRMeshImpl.get_vertices(instance);
    }

    pub fn get_indices(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRMeshImpl.get_indices(instance);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRMeshImpl.get_lastChangedTime(instance);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyerror!?DOMString {
        return try XRMeshImpl.get_semanticLabel(instance);
    }

};

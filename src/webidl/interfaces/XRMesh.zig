//! Generated from: real-world-meshing.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRMeshImpl = @import("impls").XRMesh;
const Float32Array = @import("interfaces").Float32Array;
const Uint32Array = @import("interfaces").Uint32Array;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const DOMString = @import("typedefs").DOMString;
const XRSpace = @import("interfaces").XRSpace;

pub const XRMesh = struct {
    pub const Meta = struct {
        pub const name = "XRMesh";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            meshSpace: XRSpace = undefined,
            vertices: runtime.FrozenArray(Float32Array) = undefined,
            indices: Uint32Array = undefined,
            lastChangedTime: DOMHighResTimeStamp = undefined,
            semanticLabel: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRMesh, .{
        .deinit_fn = &deinit_wrapper,

        .get_indices = &get_indices,
        .get_lastChangedTime = &get_lastChangedTime,
        .get_meshSpace = &get_meshSpace,
        .get_semanticLabel = &get_semanticLabel,
        .get_vertices = &get_vertices,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XRMeshImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRMeshImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_meshSpace(instance: *runtime.Instance) anyerror!XRSpace {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_meshSpace) |cached| {
            return cached;
        }
        const value = try XRMeshImpl.get_meshSpace(instance);
        state.cached_meshSpace = value;
        return value;
    }

    pub fn get_vertices(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRMeshImpl.get_vertices(instance);
    }

    pub fn get_indices(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRMeshImpl.get_indices(instance);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRMeshImpl.get_lastChangedTime(instance);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyerror!DOMString {
        return try XRMeshImpl.get_semanticLabel(instance);
    }

};

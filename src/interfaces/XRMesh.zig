//! Generated from: real-world-meshing.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRMeshImpl = @import("../impls/XRMesh.zig");

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
            vertices: FrozenArray<Float32Array> = undefined,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRMeshImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRMeshImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_meshSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_meshSpace) |cached| {
            return cached;
        }
        const value = XRMeshImpl.get_meshSpace(state);
        state.cached_meshSpace = value;
        return value;
    }

    pub fn get_vertices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRMeshImpl.get_vertices(state);
    }

    pub fn get_indices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRMeshImpl.get_indices(state);
    }

    pub fn get_lastChangedTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRMeshImpl.get_lastChangedTime(state);
    }

    pub fn get_semanticLabel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRMeshImpl.get_semanticLabel(state);
    }

};

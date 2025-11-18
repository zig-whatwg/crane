//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPURenderPipelineImpl = @import("../impls/GPURenderPipeline.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");
const GPUPipelineBase = @import("GPUPipelineBase.zig");

pub const GPURenderPipeline = struct {
    pub const Meta = struct {
        pub const name = "GPURenderPipeline";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
            GPUPipelineBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPURenderPipeline, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_getBindGroupLayout = &call_getBindGroupLayout,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPURenderPipelineImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPURenderPipelineImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPURenderPipelineImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPURenderPipelineImpl.set_label(state, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBindGroupLayout(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return GPURenderPipelineImpl.call_getBindGroupLayout(state, index);
    }

};

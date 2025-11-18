//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUComputePipelineImpl = @import("impls").GPUComputePipeline;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUPipelineBase = @import("interfaces").GPUPipelineBase;
const GPUBindGroupLayout = @import("interfaces").GPUBindGroupLayout;

pub const GPUComputePipeline = struct {
    pub const Meta = struct {
        pub const name = "GPUComputePipeline";
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

    pub const vtable = runtime.buildVTable(GPUComputePipeline, .{
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
        
        // Initialize the instance (Impl receives full instance)
        GPUComputePipelineImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUComputePipelineImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUComputePipelineImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUComputePipelineImpl.set_label(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBindGroupLayout(instance: *runtime.Instance, index: u32) anyerror!GPUBindGroupLayout {
        // [NewObject] - Caller owns the returned object
        
        return try GPUComputePipelineImpl.call_getBindGroupLayout(instance, index);
    }

};

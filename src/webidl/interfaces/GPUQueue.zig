//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUQueueImpl = @import("impls").GPUQueue;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const GPUTexelCopyBufferLayout = @import("dictionaries").GPUTexelCopyBufferLayout;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUCopyExternalImageSourceInfo = @import("dictionaries").GPUCopyExternalImageSourceInfo;
const GPUTexelCopyTextureInfo = @import("dictionaries").GPUTexelCopyTextureInfo;
const GPUCopyExternalImageDestInfo = @import("dictionaries").GPUCopyExternalImageDestInfo;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const GPUExtent3D = @import("typedefs").GPUExtent3D;

pub const GPUQueue = struct {
    pub const Meta = struct {
        pub const name = "GPUQueue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
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

    pub const vtable = runtime.buildVTable(GPUQueue, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_copyExternalImageToTexture = &call_copyExternalImageToTexture,
        .call_onSubmittedWorkDone = &call_onSubmittedWorkDone,
        .call_submit = &call_submit,
        .call_writeBuffer = &call_writeBuffer,
        .call_writeTexture = &call_writeTexture,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUQueueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUQueueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUQueueImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUQueueImpl.set_label(instance, value);
    }

    pub fn call_onSubmittedWorkDone(instance: *runtime.Instance) anyerror!anyopaque {
        return try GPUQueueImpl.call_onSubmittedWorkDone(instance);
    }

    pub fn call_writeBuffer(instance: *runtime.Instance, buffer: GPUBuffer, bufferOffset: GPUSize64, data: AllowSharedBufferSource, dataOffset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPUQueueImpl.call_writeBuffer(instance, buffer, bufferOffset, data, dataOffset, size);
    }

    pub fn call_writeTexture(instance: *runtime.Instance, destination: GPUTexelCopyTextureInfo, data: AllowSharedBufferSource, dataLayout: GPUTexelCopyBufferLayout, size: GPUExtent3D) anyerror!void {
        
        return try GPUQueueImpl.call_writeTexture(instance, destination, data, dataLayout, size);
    }

    pub fn call_submit(instance: *runtime.Instance, commandBuffers: anyopaque) anyerror!void {
        
        return try GPUQueueImpl.call_submit(instance, commandBuffers);
    }

    pub fn call_copyExternalImageToTexture(instance: *runtime.Instance, source: GPUCopyExternalImageSourceInfo, destination: GPUCopyExternalImageDestInfo, copySize: GPUExtent3D) anyerror!void {
        
        return try GPUQueueImpl.call_copyExternalImageToTexture(instance, source, destination, copySize);
    }

};

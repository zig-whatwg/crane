//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCommandEncoderImpl = @import("impls").GPUCommandEncoder;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUCommandsMixin = @import("interfaces").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("interfaces").GPUDebugCommandsMixin;
const GPURenderPassDescriptor = @import("dictionaries").GPURenderPassDescriptor;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPUCommandBuffer = @import("interfaces").GPUCommandBuffer;
const GPUExtent3D = @import("typedefs").GPUExtent3D;
const GPURenderPassEncoder = @import("interfaces").GPURenderPassEncoder;
const GPUCommandBufferDescriptor = @import("dictionaries").GPUCommandBufferDescriptor;
const GPUComputePassDescriptor = @import("dictionaries").GPUComputePassDescriptor;
const GPUComputePassEncoder = @import("interfaces").GPUComputePassEncoder;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUTexelCopyTextureInfo = @import("dictionaries").GPUTexelCopyTextureInfo;
const GPUQuerySet = @import("interfaces").GPUQuerySet;
const GPUTexelCopyBufferInfo = @import("dictionaries").GPUTexelCopyBufferInfo;

pub const GPUCommandEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPUCommandEncoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
            GPUCommandsMixin,
            GPUDebugCommandsMixin,
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

    pub const vtable = runtime.buildVTable(GPUCommandEncoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,

        .set_label = &set_label,

        .call_beginComputePass = &call_beginComputePass,
        .call_beginRenderPass = &call_beginRenderPass,
        .call_clearBuffer = &call_clearBuffer,
        .call_copyBufferToBuffer = &call_copyBufferToBuffer,
        .call_copyBufferToTexture = &call_copyBufferToTexture,
        .call_copyTextureToBuffer = &call_copyTextureToBuffer,
        .call_copyTextureToTexture = &call_copyTextureToTexture,
        .call_finish = &call_finish,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_resolveQuerySet = &call_resolveQuerySet,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUCommandEncoderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCommandEncoderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUCommandEncoderImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUCommandEncoderImpl.set_label(instance, value);
    }

    /// Arguments for copyBufferToBuffer (WebIDL overloading)
    pub const CopyBufferToBufferArgs = union(enum) {
        /// copyBufferToBuffer(source, destination, size)
        GPUBuffer_GPUBuffer_GPUSize64: struct {
            source: GPUBuffer,
            destination: GPUBuffer,
            size: GPUSize64,
        },
        /// copyBufferToBuffer(source, sourceOffset, destination, destinationOffset, size)
        GPUBuffer_GPUSize64_GPUBuffer_GPUSize64_GPUSize64: struct {
            source: GPUBuffer,
            sourceOffset: GPUSize64,
            destination: GPUBuffer,
            destinationOffset: GPUSize64,
            size: GPUSize64,
        },
    };

    pub fn call_copyBufferToBuffer(instance: *runtime.Instance, args: CopyBufferToBufferArgs) anyerror!void {
        switch (args) {
            .GPUBuffer_GPUBuffer_GPUSize64 => |a| return try GPUCommandEncoderImpl.GPUBuffer_GPUBuffer_GPUSize64(instance, a.source, a.destination, a.size),
            .GPUBuffer_GPUSize64_GPUBuffer_GPUSize64_GPUSize64 => |a| return try GPUCommandEncoderImpl.GPUBuffer_GPUSize64_GPUBuffer_GPUSize64_GPUSize64(instance, a.source, a.sourceOffset, a.destination, a.destinationOffset, a.size),
        }
    }

    pub fn call_copyTextureToBuffer(instance: *runtime.Instance, source: GPUTexelCopyTextureInfo, destination: GPUTexelCopyBufferInfo, copySize: GPUExtent3D) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_copyTextureToBuffer(instance, source, destination, copySize);
    }

    pub fn call_copyBufferToTexture(instance: *runtime.Instance, source: GPUTexelCopyBufferInfo, destination: GPUTexelCopyTextureInfo, copySize: GPUExtent3D) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_copyBufferToTexture(instance, source, destination, copySize);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
        return try GPUCommandEncoderImpl.call_popDebugGroup(instance);
    }

    pub fn call_copyTextureToTexture(instance: *runtime.Instance, source: GPUTexelCopyTextureInfo, destination: GPUTexelCopyTextureInfo, copySize: GPUExtent3D) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_copyTextureToTexture(instance, source, destination, copySize);
    }

    pub fn call_resolveQuerySet(instance: *runtime.Instance, querySet: GPUQuerySet, firstQuery: GPUSize32, queryCount: GPUSize32, destination: GPUBuffer, destinationOffset: GPUSize64) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_resolveQuerySet(instance, querySet, firstQuery, queryCount, destination, destinationOffset);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_finish(instance: *runtime.Instance, descriptor: GPUCommandBufferDescriptor) anyerror!GPUCommandBuffer {
        
        return try GPUCommandEncoderImpl.call_finish(instance, descriptor);
    }

    pub fn call_beginComputePass(instance: *runtime.Instance, descriptor: GPUComputePassDescriptor) anyerror!GPUComputePassEncoder {
        
        return try GPUCommandEncoderImpl.call_beginComputePass(instance, descriptor);
    }

    pub fn call_beginRenderPass(instance: *runtime.Instance, descriptor: GPURenderPassDescriptor) anyerror!GPURenderPassEncoder {
        
        return try GPUCommandEncoderImpl.call_beginRenderPass(instance, descriptor);
    }

    pub fn call_clearBuffer(instance: *runtime.Instance, buffer: GPUBuffer, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_clearBuffer(instance, buffer, offset, size);
    }

};

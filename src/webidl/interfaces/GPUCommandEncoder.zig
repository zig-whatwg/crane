//! Generated from: webgpu.idl
//! Generated at: 2025-11-24T18:47:07Z
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
const USVString = @import("interfaces").USVString;
const GPURenderPassEncoder = @import("interfaces").GPURenderPassEncoder;
const GPUComputePassEncoder = @import("interfaces").GPUComputePassEncoder;
const GPUCommandBufferDescriptor = @import("dictionaries").GPUCommandBufferDescriptor;
const GPUComputePassDescriptor = @import("dictionaries").GPUComputePassDescriptor;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUTexelCopyTextureInfo = @import("dictionaries").GPUTexelCopyTextureInfo;
const GPUQuerySet = @import("interfaces").GPUQuerySet;
const GPUTexelCopyBufferInfo = @import("dictionaries").GPUTexelCopyBufferInfo;

pub const GPUCommandEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPUCommandEncoder";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "beginRenderPass", "call_beginRenderPass", 1 },
            .{ "beginComputePass", "call_beginComputePass", 0 },
            .{ "copyBufferToBuffer", "call_copyBufferToBuffer", 2 },
            .{ "copyBufferToBuffer", "call_copyBufferToBuffer", 4 },
            .{ "copyBufferToTexture", "call_copyBufferToTexture", 3 },
            .{ "copyTextureToBuffer", "call_copyTextureToBuffer", 3 },
            .{ "copyTextureToTexture", "call_copyTextureToTexture", 3 },
            .{ "clearBuffer", "call_clearBuffer", 1 },
            .{ "resolveQuerySet", "call_resolveQuerySet", 5 },
            .{ "finish", "call_finish", 0 },
            .{ "pushDebugGroup", "call_pushDebugGroup", 1 },
            .{ "popDebugGroup", "call_popDebugGroup", 0 },
            .{ "insertDebugMarker", "call_insertDebugMarker", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "beginRenderPass",
            "beginComputePass",
            "copyBufferToBuffer",
            "copyBufferToBuffer",
            "copyBufferToTexture",
            "copyTextureToBuffer",
            "copyTextureToTexture",
            "clearBuffer",
            "resolveQuerySet",
            "finish",
            "pushDebugGroup",
            "popDebugGroup",
            "insertDebugMarker",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "label", "get_label", "set_label" },
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
            label: runtime.USVString = undefined,
            _internal: ?*GPUCommandEncoderImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUCommandEncoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCommandEncoderImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUCommandEncoderImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUCommandEncoderImpl.set_label(instance, value);
    }

    pub fn call_copyBufferToBuffer(instance: *runtime.Instance, source: *runtime.Instance, destination: *runtime.Instance, size: GPUSize64) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_copyBufferToBuffer(instance, source, destination, size);
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

    pub fn call_resolveQuerySet(instance: *runtime.Instance, querySet: *runtime.Instance, firstQuery: GPUSize32, queryCount: GPUSize32, destination: *runtime.Instance, destinationOffset: GPUSize64) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_resolveQuerySet(instance, querySet, firstQuery, queryCount, destination, destinationOffset);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_finish(instance: *runtime.Instance, descriptor: GPUCommandBufferDescriptor) anyerror!*runtime.Instance {
        
        return try GPUCommandEncoderImpl.call_finish(instance, descriptor);
    }

    pub fn call_beginComputePass(instance: *runtime.Instance, descriptor: GPUComputePassDescriptor) anyerror!*runtime.Instance {
        
        return try GPUCommandEncoderImpl.call_beginComputePass(instance, descriptor);
    }

    pub fn call_beginRenderPass(instance: *runtime.Instance, descriptor: GPURenderPassDescriptor) anyerror!*runtime.Instance {
        
        return try GPUCommandEncoderImpl.call_beginRenderPass(instance, descriptor);
    }

    pub fn call_clearBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, offset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPUCommandEncoderImpl.call_clearBuffer(instance, buffer, offset, size);
    }

};

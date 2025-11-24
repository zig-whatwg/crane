//! Generated from: webgpu.idl
//! Generated at: 2025-11-24T18:47:07Z
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
const GPUCommandBuffer = @import("interfaces").GPUCommandBuffer;
const GPUCopyExternalImageDestInfo = @import("dictionaries").GPUCopyExternalImageDestInfo;
const GPUExtent3D = @import("typedefs").GPUExtent3D;
const USVString = @import("interfaces").USVString;

pub const GPUQueue = struct {
    pub const Meta = struct {
        pub const name = "GPUQueue";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "submit", "call_submit", 1 },
            .{ "onSubmittedWorkDone", "call_onSubmittedWorkDone", 0 },
            .{ "writeBuffer", "call_writeBuffer", 3 },
            .{ "writeTexture", "call_writeTexture", 4 },
            .{ "copyExternalImageToTexture", "call_copyExternalImageToTexture", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "submit",
            "onSubmittedWorkDone",
            "writeBuffer",
            "writeTexture",
            "copyExternalImageToTexture",
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
            _internal: ?*GPUQueueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_label = &get_label,

        .set_label = &set_label,

        .call_copyExternalImageToTexture = &call_copyExternalImageToTexture,
        .call_onSubmittedWorkDone = &call_onSubmittedWorkDone,
        .call_submit = &call_submit,
        .call_writeBuffer = &call_writeBuffer,
        .call_writeTexture = &call_writeTexture,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUQueueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUQueueImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUQueueImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUQueueImpl.set_label(instance, value);
    }

    pub fn call_onSubmittedWorkDone(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GPUQueueImpl.call_onSubmittedWorkDone(instance);
    }

    pub fn call_writeBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, bufferOffset: GPUSize64, data: AllowSharedBufferSource, dataOffset: GPUSize64, size: GPUSize64) anyerror!void {
        
        return try GPUQueueImpl.call_writeBuffer(instance, buffer, bufferOffset, data, dataOffset, size);
    }

    pub fn call_writeTexture(instance: *runtime.Instance, destination: GPUTexelCopyTextureInfo, data: AllowSharedBufferSource, dataLayout: GPUTexelCopyBufferLayout, size: GPUExtent3D) anyerror!void {
        
        return try GPUQueueImpl.call_writeTexture(instance, destination, data, dataLayout, size);
    }

    pub fn call_submit(instance: *runtime.Instance, commandBuffers: *const anyopaque) anyerror!void {
        
        return try GPUQueueImpl.call_submit(instance, commandBuffers);
    }

    pub fn call_copyExternalImageToTexture(instance: *runtime.Instance, source: GPUCopyExternalImageSourceInfo, destination: GPUCopyExternalImageDestInfo, copySize: GPUExtent3D) anyerror!void {
        
        return try GPUQueueImpl.call_copyExternalImageToTexture(instance, source, destination, copySize);
    }

};

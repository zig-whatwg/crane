//! Generated from: webgpu.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUComputePassEncoderImpl = @import("impls").GPUComputePassEncoder;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPUCommandsMixin = @import("interfaces").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("interfaces").GPUDebugCommandsMixin;
const GPUBindingCommandsMixin = @import("interfaces").GPUBindingCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPUSize32 = @import("typedefs").GPUSize32;
const USVString = @import("interfaces").USVString;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUComputePipeline = @import("interfaces").GPUComputePipeline;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;

pub const GPUComputePassEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPUComputePassEncoder";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            GPUObjectBase,
            GPUCommandsMixin,
            GPUDebugCommandsMixin,
            GPUBindingCommandsMixin,
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
            .{ "setPipeline", "call_setPipeline", 1 },
            .{ "dispatchWorkgroups", "call_dispatchWorkgroups", 1 },
            .{ "dispatchWorkgroupsIndirect", "call_dispatchWorkgroupsIndirect", 2 },
            .{ "end", "call_end", 0 },
            .{ "pushDebugGroup", "call_pushDebugGroup", 1 },
            .{ "popDebugGroup", "call_popDebugGroup", 0 },
            .{ "insertDebugMarker", "call_insertDebugMarker", 1 },
            .{ "setBindGroup", "call_setBindGroup", 2 },
            .{ "setBindGroup", "call_setBindGroup", 5 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPipeline",
            "dispatchWorkgroups",
            "dispatchWorkgroupsIndirect",
            "end",
            "pushDebugGroup",
            "popDebugGroup",
            "insertDebugMarker",
            "setBindGroup",
            "setBindGroup",
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
            _internal: ?*GPUComputePassEncoderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_label = &get_label,

        .set_label = &set_label,

        .call_dispatchWorkgroups = &call_dispatchWorkgroups,
        .call_dispatchWorkgroupsIndirect = &call_dispatchWorkgroupsIndirect,
        .call_end = &call_end,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_setBindGroup = &call_setBindGroup,
        .call_setPipeline = &call_setPipeline,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUComputePassEncoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUComputePassEncoderImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUComputePassEncoderImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUComputePassEncoderImpl.set_label(instance, value);
    }

    pub fn call_dispatchWorkgroups(instance: *runtime.Instance, workgroupCountX: GPUSize32, workgroupCountY: GPUSize32, workgroupCountZ: GPUSize32) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_dispatchWorkgroups(instance, workgroupCountX, workgroupCountY, workgroupCountZ);
    }

    pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
        return try GPUComputePassEncoderImpl.call_popDebugGroup(instance);
    }

    pub fn call_setBindGroup(instance: *runtime.Instance, index: GPUIndex32, bindGroup: *runtime.Instance, dynamicOffsets: *const anyopaque) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_setBindGroup(instance, index, bindGroup, dynamicOffsets);
    }

    pub fn call_dispatchWorkgroupsIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_dispatchWorkgroupsIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_insertDebugMarker(instance, markerLabel);
    }

    pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_pushDebugGroup(instance, groupLabel);
    }

    pub fn call_end(instance: *runtime.Instance) anyerror!void {
        return try GPUComputePassEncoderImpl.call_end(instance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) anyerror!void {
        
        return try GPUComputePassEncoderImpl.call_setPipeline(instance, pipeline);
    }

};

//! Generated from: webgpu.idl
//! Generated at: 2025-11-29T11:15:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPURenderCommandsMixinImpl = @import("impls").GPURenderCommandsMixin;
const mixins = @import("mixins");
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPUIndexFormat = @import("enums").GPUIndexFormat;

pub const GPURenderCommandsMixin = struct {
    pub const Meta = struct {
        pub const name = "GPURenderCommandsMixin";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPipeline", "call_setPipeline", 1 },
            .{ "setIndexBuffer", "call_setIndexBuffer", 2 },
            .{ "setVertexBuffer", "call_setVertexBuffer", 2 },
            .{ "draw", "call_draw", 1 },
            .{ "drawIndexed", "call_drawIndexed", 1 },
            .{ "drawIndirect", "call_drawIndirect", 2 },
            .{ "drawIndexedIndirect", "call_drawIndexedIndirect", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPipeline",
            "setIndexBuffer",
            "setVertexBuffer",
            "draw",
            "drawIndexed",
            "drawIndirect",
            "drawIndexedIndirect",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*GPURenderCommandsMixinImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_draw = &call_draw,
        .call_drawIndexed = &call_drawIndexed,
        .call_drawIndexedIndirect = &call_drawIndexedIndirect,
        .call_drawIndirect = &call_drawIndirect,
        .call_setIndexBuffer = &call_setIndexBuffer,
        .call_setPipeline = &call_setPipeline,
        .call_setVertexBuffer = &call_setVertexBuffer,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPURenderCommandsMixinImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderCommandsMixinImpl.deinit(instance);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: GPUSize32, instanceCount: webidl.Opt(GPUSize32), firstVertex: webidl.Opt(GPUSize32), firstInstance: webidl.Opt(GPUSize32)) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: GPUIndex32, buffer: ?*runtime.Instance, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, indexFormat: GPUIndexFormat, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: GPUSize32, instanceCount: webidl.Opt(GPUSize32), firstIndex: webidl.Opt(GPUSize32), baseVertex: webidl.Opt(GPUSignedOffset32), firstInstance: webidl.Opt(GPUSize32)) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) anyerror!void {
        
        return try GPURenderCommandsMixinImpl.call_setPipeline(instance, pipeline);
    }

};

//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPURenderCommandsMixinImpl = @import("impls").GPURenderCommandsMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
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
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

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
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*GPURenderCommandsMixinImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPURenderCommandsMixin")) {
            if (comptime @hasDecl(impls.GPURenderCommandsMixin, "installHooks")) impls.GPURenderCommandsMixin.installHooks();
        }
    }

    pub fn call_setVertexBuffer(instance: *runtime.Instance, slot: GPUIndex32, buffer: ?*runtime.Instance, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_setVertexBuffer(instance, slot, buffer, offset, size);
    }

    pub fn call_setIndexBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, indexFormat: GPUIndexFormat, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_setIndexBuffer(instance, buffer, indexFormat, offset, size);
    }

    pub fn call_drawIndexedIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_drawIndexedIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_draw(instance: *runtime.Instance, vertexCount: GPUSize32, instanceCount: webidl.Opt(GPUSize32), firstVertex: webidl.Opt(GPUSize32), firstInstance: webidl.Opt(GPUSize32)) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_draw(instance, vertexCount, instanceCount, firstVertex, firstInstance);
    }

    pub fn call_drawIndexed(instance: *runtime.Instance, indexCount: GPUSize32, instanceCount: webidl.Opt(GPUSize32), firstIndex: webidl.Opt(GPUSize32), baseVertex: webidl.Opt(GPUSignedOffset32), firstInstance: webidl.Opt(GPUSize32)) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_drawIndexed(instance, indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
    }

    pub fn call_drawIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_drawIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) anyerror!void {
        return try GPURenderCommandsMixinImpl.call_setPipeline(instance, pipeline);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_setVertexBuffer", 1, "GPUBuffer" },
        .{ "call_setIndexBuffer", 0, "GPUBuffer" },
        .{ "call_drawIndexedIndirect", 0, "GPUBuffer" },
        .{ "call_drawIndirect", 0, "GPUBuffer" },
        .{ "call_setPipeline", 0, "GPURenderPipeline" },
    };
};

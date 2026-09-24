//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPURenderPassEncoderImpl = @import("impls").GPURenderPassEncoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const GPUCommandsMixin = @import("mixins").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("mixins").GPUDebugCommandsMixin;
const GPUBindingCommandsMixin = @import("mixins").GPUBindingCommandsMixin;
const GPURenderCommandsMixin = @import("mixins").GPURenderCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUIntegerCoordinate = @import("typedefs").GPUIntegerCoordinate;
const GPUStencilValue = @import("typedefs").GPUStencilValue;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPURenderBundle = @import("interfaces").GPURenderBundle;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const USVString = @import("typedefs").USVString;
const GPUIndexFormat = @import("enums").GPUIndexFormat;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPUColor = @import("typedefs").GPUColor;

pub const GPURenderPassEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPURenderPassEncoder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            GPUObjectBase,
            GPUCommandsMixin,
            GPUDebugCommandsMixin,
            GPUBindingCommandsMixin,
            GPURenderCommandsMixin,
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

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setViewport", "call_setViewport", 6 },
            .{ "setScissorRect", "call_setScissorRect", 4 },
            .{ "setBlendConstant", "call_setBlendConstant", 1 },
            .{ "setStencilReference", "call_setStencilReference", 1 },
            .{ "beginOcclusionQuery", "call_beginOcclusionQuery", 1 },
            .{ "endOcclusionQuery", "call_endOcclusionQuery", 0 },
            .{ "executeBundles", "call_executeBundles", 1 },
            .{ "end", "call_end", 0 },
            .{ "pushDebugGroup", "call_pushDebugGroup", 1 },
            .{ "popDebugGroup", "call_popDebugGroup", 0 },
            .{ "insertDebugMarker", "call_insertDebugMarker", 1 },
            .{ "setBindGroup", "call_setBindGroup", 2 },
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
            "setViewport",
            "setScissorRect",
            "setBlendConstant",
            "setStencilReference",
            "beginOcclusionQuery",
            "endOcclusionQuery",
            "executeBundles",
            "end",
            "pushDebugGroup",
            "popDebugGroup",
            "insertDebugMarker",
            "setBindGroup",
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
        pub const eager_properties = .{
            .{ "label", "get_label", "set_label" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            label: runtime.USVString = undefined,
            _internal: ?*GPURenderPassEncoderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_label = &get_label,

        .set_label = &set_label,

        .call_beginOcclusionQuery = &call_beginOcclusionQuery,
        .call_draw = &call_draw,
        .call_drawIndexed = &call_drawIndexed,
        .call_drawIndexedIndirect = &call_drawIndexedIndirect,
        .call_drawIndirect = &call_drawIndirect,
        .call_end = &call_end,
        .call_endOcclusionQuery = &call_endOcclusionQuery,
        .call_executeBundles = &call_executeBundles,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_setBindGroup = &call_setBindGroup,
        .call_setBlendConstant = &call_setBlendConstant,
        .call_setIndexBuffer = &call_setIndexBuffer,
        .call_setPipeline = &call_setPipeline,
        .call_setScissorRect = &call_setScissorRect,
        .call_setStencilReference = &call_setStencilReference,
        .call_setVertexBuffer = &call_setVertexBuffer,
        .call_setViewport = &call_setViewport,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPURenderPassEncoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return GPURenderPassEncoderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderPassEncoderImpl.deinit(instance);
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub const call_setVertexBuffer = mixins.GPURenderCommandsMixin.call_setVertexBuffer;

    pub fn call_endOcclusionQuery(instance: *runtime.Instance) anyerror!void {
        return try GPURenderPassEncoderImpl.call_endOcclusionQuery(instance);
    }

    pub fn call_executeBundles(instance: *runtime.Instance, bundles: runtime.JSValue) anyerror!void {
        return try GPURenderPassEncoderImpl.call_executeBundles(instance, bundles);
    }

    pub fn call_setScissorRect(instance: *runtime.Instance, x: GPUIntegerCoordinate, y: GPUIntegerCoordinate, width: GPUIntegerCoordinate, height: GPUIntegerCoordinate) anyerror!void {
        return try GPURenderPassEncoderImpl.call_setScissorRect(instance, x, y, width, height);
    }

    pub const call_setIndexBuffer = mixins.GPURenderCommandsMixin.call_setIndexBuffer;

    pub const call_drawIndexedIndirect = mixins.GPURenderCommandsMixin.call_drawIndexedIndirect;

    pub fn call_setBlendConstant(instance: *runtime.Instance, color: GPUColor) anyerror!void {
        return try GPURenderPassEncoderImpl.call_setBlendConstant(instance, color);
    }

    pub const call_insertDebugMarker = mixins.GPUDebugCommandsMixin.call_insertDebugMarker;

    pub const call_drawIndexed = mixins.GPURenderCommandsMixin.call_drawIndexed;

    pub const call_drawIndirect = mixins.GPURenderCommandsMixin.call_drawIndirect;

    pub const call_popDebugGroup = mixins.GPUDebugCommandsMixin.call_popDebugGroup;

    pub fn call_setStencilReference(instance: *runtime.Instance, reference: GPUStencilValue) anyerror!void {
        return try GPURenderPassEncoderImpl.call_setStencilReference(instance, reference);
    }

    pub fn call_beginOcclusionQuery(instance: *runtime.Instance, queryIndex: GPUSize32) anyerror!void {
        return try GPURenderPassEncoderImpl.call_beginOcclusionQuery(instance, queryIndex);
    }

    pub const call_setBindGroup = mixins.GPUBindingCommandsMixin.call_setBindGroup;

    pub fn call_setViewport(instance: *runtime.Instance, x: f32, y: f32, width: f32, height: f32, minDepth: f32, maxDepth: f32) anyerror!void {
        return try GPURenderPassEncoderImpl.call_setViewport(instance, x, y, width, height, minDepth, maxDepth);
    }

    pub const call_draw = mixins.GPURenderCommandsMixin.call_draw;

    pub const call_pushDebugGroup = mixins.GPUDebugCommandsMixin.call_pushDebugGroup;

    pub const call_setPipeline = mixins.GPURenderCommandsMixin.call_setPipeline;

    pub fn call_end(instance: *runtime.Instance) anyerror!void {
        return try GPURenderPassEncoderImpl.call_end(instance);
    }

    pub const call_setBindGroup__1 = mixins.GPUBindingCommandsMixin.call_setBindGroup__1;

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "setBindGroup", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_setBindGroup", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUBindGroup")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUBindGroup.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.sequence}, .optionality = .optional } } },
            .{ .function = "call_setBindGroup__1", .implemented = @hasDecl(mixins.GPUBindingCommandsMixin.impl, "call_setBindGroup__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUBindGroup")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUBindGroup.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.{ .typed_array = "Uint32Array" }} }, .{ .kinds = &.{.other} }, .{ .kinds = &.{.other} } } },
        } },
    };
};

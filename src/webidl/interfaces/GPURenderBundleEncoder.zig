//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPURenderBundleEncoderImpl = @import("impls").GPURenderBundleEncoder;
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
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPURenderBundle = @import("interfaces").GPURenderBundle;
const GPUSize32 = @import("typedefs").GPUSize32;
const GPUIndexFormat = @import("enums").GPUIndexFormat;
const USVString = @import("typedefs").USVString;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUSignedOffset32 = @import("typedefs").GPUSignedOffset32;
const GPURenderBundleDescriptor = @import("dictionaries").GPURenderBundleDescriptor;

pub const GPURenderBundleEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPURenderBundleEncoder";
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
            .{ "finish", "call_finish", 0 },
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
            "finish",
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
            _internal: ?*GPURenderBundleEncoderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_label = &get_label,

        .set_label = &set_label,

        .call_draw = &call_draw,
        .call_drawIndexed = &call_drawIndexed,
        .call_drawIndexedIndirect = &call_drawIndexedIndirect,
        .call_drawIndirect = &call_drawIndirect,
        .call_finish = &call_finish,
        .call_insertDebugMarker = &call_insertDebugMarker,
        .call_popDebugGroup = &call_popDebugGroup,
        .call_pushDebugGroup = &call_pushDebugGroup,
        .call_setBindGroup = &call_setBindGroup,
        .call_setIndexBuffer = &call_setIndexBuffer,
        .call_setPipeline = &call_setPipeline,
        .call_setVertexBuffer = &call_setVertexBuffer,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPURenderBundleEncoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return GPURenderBundleEncoderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPURenderBundleEncoderImpl.deinit(instance);
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub fn call_finish(instance: *runtime.Instance, descriptor: webidl.Opt(GPURenderBundleDescriptor)) anyerror!*runtime.Instance {
        return try GPURenderBundleEncoderImpl.call_finish(instance, descriptor);
    }

    pub const call_setVertexBuffer = mixins.GPURenderCommandsMixin.call_setVertexBuffer;

    pub const call_setBindGroup = mixins.GPUBindingCommandsMixin.call_setBindGroup;

    pub const call_setIndexBuffer = mixins.GPURenderCommandsMixin.call_setIndexBuffer;

    pub const call_drawIndexedIndirect = mixins.GPURenderCommandsMixin.call_drawIndexedIndirect;

    pub const call_draw = mixins.GPURenderCommandsMixin.call_draw;

    pub const call_drawIndexed = mixins.GPURenderCommandsMixin.call_drawIndexed;

    pub const call_insertDebugMarker = mixins.GPUDebugCommandsMixin.call_insertDebugMarker;

    pub const call_pushDebugGroup = mixins.GPUDebugCommandsMixin.call_pushDebugGroup;

    pub const call_setPipeline = mixins.GPURenderCommandsMixin.call_setPipeline;

    pub const call_popDebugGroup = mixins.GPUDebugCommandsMixin.call_popDebugGroup;

    pub const call_drawIndirect = mixins.GPURenderCommandsMixin.call_drawIndirect;

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

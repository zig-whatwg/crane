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

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("GPURenderBundleEncoder has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "init") and @hasDecl(GPURenderBundleEncoderImpl, "initOwn")) @compileError("GPURenderBundleEncoderImpl defines both init and initOwn");
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "init")) return GPURenderBundleEncoderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPURenderBundleEncoderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "init")) return false;
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "construction_args")) {
            inline for (GPURenderBundleEncoderImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "deinit") and @hasDecl(GPURenderBundleEncoderImpl, "deinitOwn")) @compileError("GPURenderBundleEncoderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "deinit")) return GPURenderBundleEncoderImpl.deinit(instance);
        if (comptime @hasDecl(GPURenderBundleEncoderImpl, "deinitOwn")) GPURenderBundleEncoderImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPURenderBundleEncoder")) {
            if (comptime @hasDecl(impls.GPURenderBundleEncoder, "installHooks")) impls.GPURenderBundleEncoder.installHooks();
        }
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
            .{ .function = "call_setBindGroup", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUBindGroup")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUBindGroup.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.sequence}, .optionality = .optional } } },
            .{ .function = "call_setBindGroup__1", .implemented = @hasDecl(mixins.GPUBindingCommandsMixin.impl, "call_setBindGroup__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "GPUBindGroup")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").GPUBindGroup.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.{ .typed_array = "Uint32Array" }} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
    };
};

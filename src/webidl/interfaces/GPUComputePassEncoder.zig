//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUComputePassEncoderImpl = @import("impls").GPUComputePassEncoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const GPUCommandsMixin = @import("mixins").GPUCommandsMixin;
const GPUDebugCommandsMixin = @import("mixins").GPUDebugCommandsMixin;
const GPUBindingCommandsMixin = @import("mixins").GPUBindingCommandsMixin;
const GPUIndex32 = @import("typedefs").GPUIndex32;
const GPUBufferDynamicOffset = @import("typedefs").GPUBufferDynamicOffset;
const GPUSize32 = @import("typedefs").GPUSize32;
const USVString = @import("typedefs").USVString;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUComputePipeline = @import("interfaces").GPUComputePipeline;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUBindGroup = @import("interfaces").GPUBindGroup;

pub const GPUComputePassEncoder = struct {
    pub const Meta = struct {
        pub const name = "GPUComputePassEncoder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPipeline", "call_setPipeline", 1 },
            .{ "dispatchWorkgroups", "call_dispatchWorkgroups", 1 },
            .{ "dispatchWorkgroupsIndirect", "call_dispatchWorkgroupsIndirect", 2 },
            .{ "end", "call_end", 0 },
            .{ "pushDebugGroup", "call_pushDebugGroup", 1 },
            .{ "popDebugGroup", "call_popDebugGroup", 0 },
            .{ "insertDebugMarker", "call_insertDebugMarker", 1 },
            .{ "setBindGroup", "call_setBindGroup", 2 },
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
            if (comptime !takesConstructionArg(field.name)) @compileError("GPUComputePassEncoder has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "init") and @hasDecl(GPUComputePassEncoderImpl, "initOwn")) @compileError("GPUComputePassEncoderImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "init")) return GPUComputePassEncoderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUComputePassEncoderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "init")) return false;
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "construction_args")) {
            inline for (GPUComputePassEncoderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "deinit") and @hasDecl(GPUComputePassEncoderImpl, "deinitOwn")) @compileError("GPUComputePassEncoderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "deinit")) return GPUComputePassEncoderImpl.deinit(instance);
        if (comptime @hasDecl(GPUComputePassEncoderImpl, "deinitOwn")) GPUComputePassEncoderImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUComputePassEncoder")) {
            if (comptime @hasDecl(impls.GPUComputePassEncoder, "installHooks")) impls.GPUComputePassEncoder.installHooks();
        }
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub fn call_dispatchWorkgroupsIndirect(instance: *runtime.Instance, indirectBuffer: *runtime.Instance, indirectOffset: GPUSize64) anyerror!void {
        return try GPUComputePassEncoderImpl.call_dispatchWorkgroupsIndirect(instance, indirectBuffer, indirectOffset);
    }

    pub const call_setBindGroup = mixins.GPUBindingCommandsMixin.call_setBindGroup;

    pub fn call_dispatchWorkgroups(instance: *runtime.Instance, workgroupCountX: GPUSize32, workgroupCountY: webidl.Opt(GPUSize32), workgroupCountZ: webidl.Opt(GPUSize32)) anyerror!void {
        return try GPUComputePassEncoderImpl.call_dispatchWorkgroups(instance, workgroupCountX, workgroupCountY, workgroupCountZ);
    }

    pub const call_insertDebugMarker = mixins.GPUDebugCommandsMixin.call_insertDebugMarker;

    pub const call_pushDebugGroup = mixins.GPUDebugCommandsMixin.call_pushDebugGroup;

    pub fn call_setPipeline(instance: *runtime.Instance, pipeline: *runtime.Instance) anyerror!void {
        return try GPUComputePassEncoderImpl.call_setPipeline(instance, pipeline);
    }

    pub const call_popDebugGroup = mixins.GPUDebugCommandsMixin.call_popDebugGroup;

    pub fn call_end(instance: *runtime.Instance) anyerror!void {
        return try GPUComputePassEncoderImpl.call_end(instance);
    }

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

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_dispatchWorkgroupsIndirect", 0, "GPUBuffer" },
        .{ "call_setBindGroup", 1, "GPUBindGroup" },
        .{ "call_setBindGroup__1", 1, "GPUBindGroup" },
        .{ "call_setPipeline", 0, "GPUComputePipeline" },
    };
};

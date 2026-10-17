//! Generated from: webnn.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLContextImpl = @import("impls").MLContext;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MLTensor = @import("interfaces").MLTensor;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const MLNamedTensors = @import("typedefs").MLNamedTensors;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUDevice = @import("interfaces").GPUDevice;
const MLOpSupportLimits = @import("dictionaries").MLOpSupportLimits;
const MLTensorDescriptor = @import("dictionaries").MLTensorDescriptor;
const MLGraph = @import("interfaces").MLGraph;
const MLOperandDescriptor = @import("dictionaries").MLOperandDescriptor;
const MLContextLostInfo = @import("dictionaries").MLContextLostInfo;

pub const MLContext = struct {
    pub const Meta = struct {
        pub const name = "MLContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "accelerated", "get_accelerated", null },
            .{ "lost", "get_lost", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "dispatch", "call_dispatch", 3 },
            .{ "createTensor", "call_createTensor", 1 },
            .{ "createExportableTensor", "call_createExportableTensor", 2 },
            .{ "createConstantTensor", "call_createConstantTensor", 2 },
            .{ "readTensor", "call_readTensor", 1 },
            .{ "writeTensor", "call_writeTensor", 2 },
            .{ "exportToGPU", "call_exportToGPU", 1 },
            .{ "opSupportLimits", "call_opSupportLimits", 0 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "dispatch",
            "createTensor",
            "createExportableTensor",
            "createConstantTensor",
            "readTensor",
            "writeTensor",
            "exportToGPU",
            "opSupportLimits",
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "accelerated", "get_accelerated", null },
            .{ "lost", "get_lost", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            accelerated: bool = undefined,
            lost: runtime.JSValue = undefined,
            _internal: ?*MLContextImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_accelerated = &get_accelerated,
        .get_lost = &get_lost,

        .call_createConstantTensor = &call_createConstantTensor,
        .call_createExportableTensor = &call_createExportableTensor,
        .call_createTensor = &call_createTensor,
        .call_destroy = &call_destroy,
        .call_dispatch = &call_dispatch,
        .call_exportToGPU = &call_exportToGPU,
        .call_opSupportLimits = &call_opSupportLimits,
        .call_readTensor = &call_readTensor,
        .call_writeTensor = &call_writeTensor,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MLContext has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MLContextImpl, "init") and @hasDecl(MLContextImpl, "initOwn")) @compileError("MLContextImpl defines both init and initOwn");
        if (comptime @hasDecl(MLContextImpl, "init")) return MLContextImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MLContextImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MLContextImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MLContextImpl, "init")) return false;
        if (comptime @hasDecl(MLContextImpl, "construction_args")) {
            inline for (MLContextImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MLContextImpl, "deinit") and @hasDecl(MLContextImpl, "deinitOwn")) @compileError("MLContextImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MLContextImpl, "deinit")) return MLContextImpl.deinit(instance);
        if (comptime @hasDecl(MLContextImpl, "deinitOwn")) MLContextImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MLContext")) {
            if (comptime @hasDecl(impls.MLContext, "installHooks")) impls.MLContext.installHooks();
        }
    }

    pub fn get_accelerated(instance: *runtime.Instance) anyerror!bool {
        return try MLContextImpl.get_accelerated(instance);
    }

    pub fn get_lost(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MLContextImpl.get_lost(instance);
    }

    pub fn call_dispatch(instance: *runtime.Instance, graph: *runtime.Instance, inputs: MLNamedTensors, outputs: MLNamedTensors) anyerror!void {
        return try MLContextImpl.call_dispatch(instance, graph, inputs, outputs);
    }

    pub fn call_opSupportLimits(instance: *runtime.Instance) anyerror!MLOpSupportLimits {
        return try MLContextImpl.call_opSupportLimits(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try MLContextImpl.call_destroy(instance);
    }

    pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: MLOperandDescriptor, inputData: AllowSharedBufferSource) anyerror!runtime.JSValue {
        return try MLContextImpl.call_createConstantTensor(instance, descriptor, inputData);
    }

    pub fn call_writeTensor(instance: *runtime.Instance, tensor: *runtime.Instance, inputData: AllowSharedBufferSource) anyerror!void {
        return try MLContextImpl.call_writeTensor(instance, tensor, inputData);
    }

    pub fn call_createTensor(instance: *runtime.Instance, descriptor: MLTensorDescriptor) anyerror!runtime.JSValue {
        return try MLContextImpl.call_createTensor(instance, descriptor);
    }

    pub fn call_exportToGPU(instance: *runtime.Instance, tensor: *runtime.Instance) anyerror!*runtime.Instance {
        return try MLContextImpl.call_exportToGPU(instance, tensor);
    }

    pub fn call_createExportableTensor(instance: *runtime.Instance, descriptor: MLTensorDescriptor, gpuDevice: *runtime.Instance) anyerror!runtime.JSValue {
        return try MLContextImpl.call_createExportableTensor(instance, descriptor, gpuDevice);
    }

    pub fn call_readTensor(instance: *runtime.Instance, tensor: *runtime.Instance) anyerror!runtime.JSValue {
        return try MLContextImpl.call_readTensor(instance, tensor);
    }

    pub fn call_readTensor__1(instance: *runtime.Instance, tensor: *runtime.Instance, outputData: AllowSharedBufferSource) anyerror!runtime.JSValue {
        if (comptime @hasDecl(MLContextImpl, "call_readTensor__1")) {
            return try MLContextImpl.call_readTensor__1(instance, tensor, outputData);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "readTensor", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_readTensor", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "MLTensor")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").MLTensor.State) } else .other)} }} },
            .{ .function = "call_readTensor__1", .implemented = @hasDecl(MLContextImpl, "call_readTensor__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "MLTensor")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").MLTensor.State) } else .other)} }, .{ .kinds = &.{ .array_buffer, .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } } } },
        } },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_createConstantTensor",
        "call_createTensor",
        "call_createExportableTensor",
        "call_readTensor",
        "call_readTensor__1",
    };
};

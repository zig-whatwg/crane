//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUQueueImpl = @import("impls").GPUQueue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const GPUTexelCopyBufferLayout = @import("dictionaries").GPUTexelCopyBufferLayout;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUCopyExternalImageSourceInfo = @import("dictionaries").GPUCopyExternalImageSourceInfo;
const GPUTexelCopyTextureInfo = @import("dictionaries").GPUTexelCopyTextureInfo;
const GPUCommandBuffer = @import("interfaces").GPUCommandBuffer;
const GPUCopyExternalImageDestInfo = @import("dictionaries").GPUCopyExternalImageDestInfo;
const GPUExtent3D = @import("typedefs").GPUExtent3D;
const USVString = @import("typedefs").USVString;

pub const GPUQueue = struct {
    pub const Meta = struct {
        pub const name = "GPUQueue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("GPUQueue has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GPUQueueImpl, "init") and @hasDecl(GPUQueueImpl, "initOwn")) @compileError("GPUQueueImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUQueueImpl, "init")) return GPUQueueImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUQueueImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUQueueImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUQueueImpl, "init")) return false;
        if (comptime @hasDecl(GPUQueueImpl, "construction_args")) {
            inline for (GPUQueueImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUQueueImpl, "deinit") and @hasDecl(GPUQueueImpl, "deinitOwn")) @compileError("GPUQueueImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUQueueImpl, "deinit")) return GPUQueueImpl.deinit(instance);
        if (comptime @hasDecl(GPUQueueImpl, "deinitOwn")) GPUQueueImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUQueue")) {
            if (comptime @hasDecl(impls.GPUQueue, "installHooks")) impls.GPUQueue.installHooks();
        }
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub fn call_onSubmittedWorkDone(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try GPUQueueImpl.call_onSubmittedWorkDone(instance);
    }

    pub fn call_submit(instance: *runtime.Instance, commandBuffers: runtime.JSValue) anyerror!void {
        return try GPUQueueImpl.call_submit(instance, commandBuffers);
    }

    pub fn call_writeBuffer(instance: *runtime.Instance, buffer: *runtime.Instance, bufferOffset: GPUSize64, data: AllowSharedBufferSource, dataOffset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!void {
        return try GPUQueueImpl.call_writeBuffer(instance, buffer, bufferOffset, data, dataOffset, size);
    }

    pub fn call_writeTexture(instance: *runtime.Instance, destination: GPUTexelCopyTextureInfo, data: AllowSharedBufferSource, dataLayout: GPUTexelCopyBufferLayout, size: GPUExtent3D) anyerror!void {
        return try GPUQueueImpl.call_writeTexture(instance, destination, data, dataLayout, size);
    }

    pub fn call_copyExternalImageToTexture(instance: *runtime.Instance, source: GPUCopyExternalImageSourceInfo, destination: GPUCopyExternalImageDestInfo, copySize: GPUExtent3D) anyerror!void {
        return try GPUQueueImpl.call_copyExternalImageToTexture(instance, source, destination, copySize);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_submit", 0, "GPUCommandBuffer" },
        .{ "call_writeBuffer", 0, "GPUBuffer" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_onSubmittedWorkDone",
    };
};

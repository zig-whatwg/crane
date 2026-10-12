//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUAdapterImpl = @import("impls").GPUAdapter;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUDeviceDescriptor = @import("dictionaries").GPUDeviceDescriptor;
const GPUSupportedLimits = @import("interfaces").GPUSupportedLimits;
const GPUSupportedFeatures = @import("interfaces").GPUSupportedFeatures;
const GPUAdapterInfo = @import("interfaces").GPUAdapterInfo;
const GPUDevice = @import("interfaces").GPUDevice;

pub const GPUAdapter = struct {
    pub const Meta = struct {
        pub const name = "GPUAdapter";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
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
            .{ "features", "get_features", null },
            .{ "limits", "get_limits", null },
            .{ "info", "get_info", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestDevice", "call_requestDevice", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestDevice",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "features", "get_features", null },
            .{ "limits", "get_limits", null },
            .{ "info", "get_info", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            features: *runtime.Instance = undefined,
            limits: *runtime.Instance = undefined,
            info: *runtime.Instance = undefined,
            cached_features: ?*runtime.Instance = null,
            cached_limits: ?*runtime.Instance = null,
            cached_info: ?*runtime.Instance = null,
            _internal: ?*GPUAdapterImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_features = &get_features,
        .get_info = &get_info,
        .get_limits = &get_limits,

        .call_requestDevice = &call_requestDevice,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("GPUAdapter has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(GPUAdapterImpl, "init") and @hasDecl(GPUAdapterImpl, "initOwn")) @compileError("GPUAdapterImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUAdapterImpl, "init")) return GPUAdapterImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUAdapterImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUAdapterImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUAdapterImpl, "init")) return false;
        if (comptime @hasDecl(GPUAdapterImpl, "construction_args")) {
            inline for (GPUAdapterImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUAdapterImpl, "deinit") and @hasDecl(GPUAdapterImpl, "deinitOwn")) @compileError("GPUAdapterImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUAdapterImpl, "deinit")) return GPUAdapterImpl.deinit(instance);
        if (comptime @hasDecl(GPUAdapterImpl, "deinitOwn")) GPUAdapterImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUAdapter")) {
            if (comptime @hasDecl(impls.GPUAdapter, "installHooks")) impls.GPUAdapter.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_features(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_features) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_features(instance);
        state.own.cached_features = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_limits(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_limits) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_limits(instance);
        state.own.cached_limits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_info(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_info) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_info(instance);
        state.own.cached_info = value;
        return value;
    }

    pub fn call_requestDevice(instance: *runtime.Instance, descriptor: webidl.Opt(GPUDeviceDescriptor)) anyerror!runtime.JSValue {
        return try GPUAdapterImpl.call_requestDevice(instance, descriptor);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_requestDevice",
    };
};

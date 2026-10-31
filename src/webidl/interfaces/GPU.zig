//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUImpl = @import("impls").GPU;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUAdapter = @import("interfaces").GPUAdapter;
const WGSLLanguageFeatures = @import("interfaces").WGSLLanguageFeatures;
const GPURequestAdapterOptions = @import("dictionaries").GPURequestAdapterOptions;
const GPUTextureFormat = @import("enums").GPUTextureFormat;

pub const GPU = struct {
    pub const Meta = struct {
        pub const name = "GPU";
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
            .{ "wgslLanguageFeatures", "get_wgslLanguageFeatures", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestAdapter", "call_requestAdapter", 0 },
            .{ "getPreferredCanvasFormat", "call_getPreferredCanvasFormat", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestAdapter",
            "getPreferredCanvasFormat",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "wgslLanguageFeatures", "get_wgslLanguageFeatures", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            wgslLanguageFeatures: *runtime.Instance = undefined,
            cached_wgslLanguageFeatures: ?*runtime.Instance = null,
            _internal: ?*GPUImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_wgslLanguageFeatures = &get_wgslLanguageFeatures,

        .call_getPreferredCanvasFormat = &call_getPreferredCanvasFormat,
        .call_requestAdapter = &call_requestAdapter,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GPU has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GPUImpl, "init") and @hasDecl(GPUImpl, "initOwn")) @compileError("GPUImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUImpl, "init")) return GPUImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUImpl, "init")) return false;
        if (comptime @hasDecl(GPUImpl, "construction_args")) {
            inline for (GPUImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUImpl, "deinit") and @hasDecl(GPUImpl, "deinitOwn")) @compileError("GPUImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(GPUImpl, "deinit")) return GPUImpl.deinit(instance);
        if (comptime @hasDecl(GPUImpl, "deinitOwn")) GPUImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPU")) {
            if (comptime @hasDecl(impls.GPU, "installHooks")) impls.GPU.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_wgslLanguageFeatures(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_wgslLanguageFeatures) |cached| {
            return cached;
        }
        const value = try GPUImpl.get_wgslLanguageFeatures(instance);
        state.own.cached_wgslLanguageFeatures = value;
        @import("dom").same_object_cache.made(instance, value, "wgslLanguageFeatures");
        return value;
    }

    pub fn call_requestAdapter(instance: *runtime.Instance, options: webidl.Opt(GPURequestAdapterOptions)) anyerror!runtime.JSValue {
        return try GPUImpl.call_requestAdapter(instance, options);
    }

    pub fn call_getPreferredCanvasFormat(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try GPUImpl.call_getPreferredCanvasFormat(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_requestAdapter",
    };
};

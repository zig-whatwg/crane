//! Generated from: shared-storage.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedStorageWorkletImpl = @import("impls").SharedStorageWorklet;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Worklet = @import("interfaces").Worklet;
const SharedStorageResponse = @import("typedefs").SharedStorageResponse;
const WorkletOptions = @import("dictionaries").WorkletOptions;
const SharedStorageUrlWithMetadata = @import("dictionaries").SharedStorageUrlWithMetadata;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const SharedStorageRunOperationMethodOptions = @import("dictionaries").SharedStorageRunOperationMethodOptions;

pub const SharedStorageWorklet = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorklet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Worklet.State;
        pub const ParentInterface = Worklet;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{"Window"} } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "selectURL", "call_selectURL", 2 },
            .{ "run", "call_run", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "selectURL",
            "run",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addModule",
        };

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
            _internal: ?*SharedStorageWorkletImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_run = &call_run,
        .call_selectURL = &call_selectURL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SharedStorageWorklet has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SharedStorageWorkletImpl, "init") and @hasDecl(SharedStorageWorkletImpl, "initOwn")) @compileError("SharedStorageWorkletImpl defines both init and initOwn");
        if (comptime @hasDecl(SharedStorageWorkletImpl, "init")) return SharedStorageWorkletImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SharedStorageWorkletImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SharedStorageWorkletImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SharedStorageWorkletImpl, "init")) return false;
        if (comptime @hasDecl(SharedStorageWorkletImpl, "construction_args")) {
            inline for (SharedStorageWorkletImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(SharedStorageWorkletImpl, "deinit") and @hasDecl(SharedStorageWorkletImpl, "deinitOwn")) @compileError("SharedStorageWorkletImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SharedStorageWorkletImpl, "deinit")) return SharedStorageWorkletImpl.deinit(instance);
        if (comptime @hasDecl(SharedStorageWorkletImpl, "deinitOwn")) SharedStorageWorkletImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SharedStorageWorklet")) {
            if (comptime @hasDecl(impls.SharedStorageWorklet, "installHooks")) impls.SharedStorageWorklet.installHooks();
        }
    }

    pub fn call_selectURL(instance: *runtime.Instance, name: DOMString, urls: runtime.JSValue, options: webidl.Opt(SharedStorageRunOperationMethodOptions)) anyerror!runtime.JSValue {
        return try SharedStorageWorkletImpl.call_selectURL(instance, name, urls, options);
    }

    pub fn call_run(instance: *runtime.Instance, name: DOMString, options: webidl.Opt(SharedStorageRunOperationMethodOptions)) anyerror!runtime.JSValue {
        return try SharedStorageWorkletImpl.call_run(instance, name, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_selectURL",
        "call_run",
    };
};

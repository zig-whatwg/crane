//! Generated from: shared-storage.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedStorageWorkletGlobalScopeImpl = @import("impls").SharedStorageWorkletGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const Function = @import("callbacks").Function;
const SharedStorageWorkletNavigator = @import("interfaces").SharedStorageWorkletNavigator;
const DOMString = @import("typedefs").DOMString;
const SharedStorage = @import("interfaces").SharedStorage;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const SharedStorageWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorkletGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkletGlobalScope.State;
        pub const ParentInterface = WorkletGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "SharedStorageWorklet" } },
            .{ .name = "Global", .value = .{ .identifier = "SharedStorageWorklet" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedStorageWorklet = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "privateAggregation", "get_privateAggregation", null },
            .{ "navigator", "get_navigator", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "register", "call_register", 2 },
            .{ "interestGroups", "call_interestGroups", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
            "interestGroups",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedStorage", "get_sharedStorage", null },
            .{ "privateAggregation", "get_privateAggregation", null },
            .{ "navigator", "get_navigator", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sharedStorage: *runtime.Instance = undefined,
            privateAggregation: *runtime.Instance = undefined,
            navigator: *runtime.Instance = undefined,
            _internal: ?*SharedStorageWorkletGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_navigator = &get_navigator,
        .get_privateAggregation = &get_privateAggregation,
        .get_sharedStorage = &get_sharedStorage,

        .call_interestGroups = &call_interestGroups,
        .call_register = &call_register,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SharedStorageWorkletGlobalScope has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "init") and @hasDecl(SharedStorageWorkletGlobalScopeImpl, "initOwn")) @compileError("SharedStorageWorkletGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "init")) return SharedStorageWorkletGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SharedStorageWorkletGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "construction_args")) {
            inline for (SharedStorageWorkletGlobalScopeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "deinit") and @hasDecl(SharedStorageWorkletGlobalScopeImpl, "deinitOwn")) @compileError("SharedStorageWorkletGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "deinit")) return SharedStorageWorkletGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(SharedStorageWorkletGlobalScopeImpl, "deinitOwn")) SharedStorageWorkletGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SharedStorageWorkletGlobalScope")) {
            if (comptime @hasDecl(impls.SharedStorageWorkletGlobalScope, "installHooks")) impls.SharedStorageWorkletGlobalScope.installHooks();
        }
    }

    pub fn get_sharedStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletGlobalScopeImpl.get_sharedStorage(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedStorageWorkletGlobalScopeImpl.get_navigator(instance);
    }

    pub fn call_interestGroups(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SharedStorageWorkletGlobalScopeImpl.call_interestGroups(instance);
    }

    pub fn call_register(instance: *runtime.Instance, name: DOMString, operationCtor: Function) anyerror!void {
        return try SharedStorageWorkletGlobalScopeImpl.call_register(instance, name, operationCtor);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_interestGroups",
    };
};

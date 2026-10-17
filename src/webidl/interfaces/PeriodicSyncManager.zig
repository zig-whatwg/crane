//! Generated from: periodic-background-sync.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PeriodicSyncManagerImpl = @import("impls").PeriodicSyncManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const BackgroundSyncOptions = @import("dictionaries").BackgroundSyncOptions;
const DOMString = @import("typedefs").DOMString;

pub const PeriodicSyncManager = struct {
    pub const Meta = struct {
        pub const name = "PeriodicSyncManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "register", "call_register", 1 },
            .{ "getTags", "call_getTags", 0 },
            .{ "unregister", "call_unregister", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
            "getTags",
            "unregister",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

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
            _internal: ?*PeriodicSyncManagerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_getTags = &call_getTags,
        .call_register = &call_register,
        .call_unregister = &call_unregister,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PeriodicSyncManager has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "init") and @hasDecl(PeriodicSyncManagerImpl, "initOwn")) @compileError("PeriodicSyncManagerImpl defines both init and initOwn");
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "init")) return PeriodicSyncManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PeriodicSyncManagerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "init")) return false;
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "construction_args")) {
            inline for (PeriodicSyncManagerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "deinit") and @hasDecl(PeriodicSyncManagerImpl, "deinitOwn")) @compileError("PeriodicSyncManagerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "deinit")) return PeriodicSyncManagerImpl.deinit(instance);
        if (comptime @hasDecl(PeriodicSyncManagerImpl, "deinitOwn")) PeriodicSyncManagerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PeriodicSyncManager")) {
            if (comptime @hasDecl(impls.PeriodicSyncManager, "installHooks")) impls.PeriodicSyncManager.installHooks();
        }
    }

    pub fn call_unregister(instance: *runtime.Instance, tag: runtime.DOMString) anyerror!runtime.JSValue {
        return try PeriodicSyncManagerImpl.call_unregister(instance, tag);
    }

    pub fn call_getTags(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PeriodicSyncManagerImpl.call_getTags(instance);
    }

    pub fn call_register(instance: *runtime.Instance, tag: runtime.DOMString, options: webidl.Opt(BackgroundSyncOptions)) anyerror!runtime.JSValue {
        return try PeriodicSyncManagerImpl.call_register(instance, tag, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_unregister",
        "call_getTags",
        "call_register",
    };
};

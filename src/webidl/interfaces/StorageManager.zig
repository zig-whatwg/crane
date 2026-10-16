//! Generated from: storage.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageManagerImpl = @import("impls").StorageManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FileSystemDirectoryHandle = @import("interfaces").FileSystemDirectoryHandle;
const StorageEstimate = @import("dictionaries").StorageEstimate;

pub const StorageManager = struct {
    pub const Meta = struct {
        pub const name = "StorageManager";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "persisted", "call_persisted", 0 },
            .{ "persist", "call_persist", 0 },
            .{ "estimate", "call_estimate", 0 },
            .{ "getDirectory", "call_getDirectory", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "persisted",
            "persist",
            "estimate",
            "getDirectory",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "getDirectory",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*StorageManagerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_estimate = &call_estimate,
        .call_getDirectory = &call_getDirectory,
        .call_persist = &call_persist,
        .call_persisted = &call_persisted,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("StorageManager has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(StorageManagerImpl, "init") and @hasDecl(StorageManagerImpl, "initOwn")) @compileError("StorageManagerImpl defines both init and initOwn");
        if (comptime @hasDecl(StorageManagerImpl, "init")) return StorageManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(StorageManagerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try StorageManagerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StorageManagerImpl, "init")) return false;
        if (comptime @hasDecl(StorageManagerImpl, "construction_args")) {
            inline for (StorageManagerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StorageManagerImpl, "deinit") and @hasDecl(StorageManagerImpl, "deinitOwn")) @compileError("StorageManagerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StorageManagerImpl, "deinit")) return StorageManagerImpl.deinit(instance);
        if (comptime @hasDecl(StorageManagerImpl, "deinitOwn")) StorageManagerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StorageManager")) {
            if (comptime @hasDecl(impls.StorageManager, "installHooks")) impls.StorageManager.installHooks();
        }
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageManagerImpl.call_getDirectory(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageManagerImpl.call_persist(instance);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageManagerImpl.call_persisted(instance);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageManagerImpl.call_estimate(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getDirectory",
        "call_persist",
        "call_persisted",
        "call_estimate",
    };
};

//! Generated from: storage-buckets.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageBucketManagerImpl = @import("impls").StorageBucketManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const StorageBucketOptions = @import("dictionaries").StorageBucketOptions;
const StorageBucket = @import("interfaces").StorageBucket;
const DOMString = @import("typedefs").DOMString;

pub const StorageBucketManager = struct {
    pub const Meta = struct {
        pub const name = "StorageBucketManager";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "open", "call_open", 1 },
            .{ "keys", "call_keys", 0 },
            .{ "delete", "call_delete", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "keys",
            "delete",
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
            _internal: ?*StorageBucketManagerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_open = &call_open,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("StorageBucketManager has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(StorageBucketManagerImpl, "init") and @hasDecl(StorageBucketManagerImpl, "initOwn")) @compileError("StorageBucketManagerImpl defines both init and initOwn");
        if (comptime @hasDecl(StorageBucketManagerImpl, "init")) return StorageBucketManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(StorageBucketManagerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try StorageBucketManagerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StorageBucketManagerImpl, "init")) return false;
        if (comptime @hasDecl(StorageBucketManagerImpl, "construction_args")) {
            inline for (StorageBucketManagerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StorageBucketManagerImpl, "deinit") and @hasDecl(StorageBucketManagerImpl, "deinitOwn")) @compileError("StorageBucketManagerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StorageBucketManagerImpl, "deinit")) return StorageBucketManagerImpl.deinit(instance);
        if (comptime @hasDecl(StorageBucketManagerImpl, "deinitOwn")) StorageBucketManagerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StorageBucketManager")) {
            if (comptime @hasDecl(impls.StorageBucketManager, "installHooks")) impls.StorageBucketManager.installHooks();
        }
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
        return try StorageBucketManagerImpl.call_delete(instance, name);
    }

    pub fn call_keys(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try StorageBucketManagerImpl.call_keys(instance);
    }

    pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, options: webidl.Opt(StorageBucketOptions)) anyerror!runtime.JSValue {
        return try StorageBucketManagerImpl.call_open(instance, name, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_delete",
        "call_keys",
        "call_open",
    };
};

//! Generated from: push-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushManagerImpl = @import("impls").PushManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PermissionState = @import("enums").PermissionState;
const PushSubscription = @import("interfaces").PushSubscription;
const PushSubscriptionOptionsInit = @import("dictionaries").PushSubscriptionOptionsInit;
const DOMString = @import("typedefs").DOMString;

pub const PushManager = struct {
    pub const Meta = struct {
        pub const name = "PushManager";
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
            .{ "subscribe", "call_subscribe", 0 },
            .{ "getSubscription", "call_getSubscription", 0 },
            .{ "permissionState", "call_permissionState", 0 },
        };

        /// Static attribute binding hints for V8Interface (JS name, getter fn name, setter fn name or null)
        pub const static_properties = .{
            .{ "supportedContentEncodings", "get_static_supportedContentEncodings", null },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "subscribe",
            "getSubscription",
            "permissionState",
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
            _internal: ?*PushManagerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_getSubscription = &call_getSubscription,
        .call_permissionState = &call_permissionState,
        .call_subscribe = &call_subscribe,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PushManager has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PushManagerImpl, "init") and @hasDecl(PushManagerImpl, "initOwn")) @compileError("PushManagerImpl defines both init and initOwn");
        if (comptime @hasDecl(PushManagerImpl, "init")) return PushManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PushManagerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PushManagerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PushManagerImpl, "init")) return false;
        if (comptime @hasDecl(PushManagerImpl, "construction_args")) {
            inline for (PushManagerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PushManagerImpl, "deinit") and @hasDecl(PushManagerImpl, "deinitOwn")) @compileError("PushManagerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PushManagerImpl, "deinit")) return PushManagerImpl.deinit(instance);
        if (comptime @hasDecl(PushManagerImpl, "deinitOwn")) PushManagerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PushManager")) {
            if (comptime @hasDecl(impls.PushManager, "installHooks")) impls.PushManager.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_static_supportedContentEncodings(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PushManagerImpl.get_static_supportedContentEncodings(instance);
    }

    pub fn call_subscribe(instance: *runtime.Instance, options: webidl.Opt(PushSubscriptionOptionsInit)) anyerror!runtime.JSValue {
        return try PushManagerImpl.call_subscribe(instance, options);
    }

    pub fn call_getSubscription(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PushManagerImpl.call_getSubscription(instance);
    }

    pub fn call_permissionState(instance: *runtime.Instance, options: webidl.Opt(PushSubscriptionOptionsInit)) anyerror!runtime.JSValue {
        return try PushManagerImpl.call_permissionState(instance, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_subscribe",
        "call_getSubscription",
        "call_permissionState",
    };
};

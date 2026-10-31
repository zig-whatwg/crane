//! Generated from: push-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushSubscriptionImpl = @import("impls").PushSubscription;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const PushSubscriptionOptions = @import("interfaces").PushSubscriptionOptions;
const PushSubscriptionJSON = @import("dictionaries").PushSubscriptionJSON;
const USVString = @import("typedefs").USVString;
const PushEncryptionKeyName = @import("enums").PushEncryptionKeyName;

pub const PushSubscription = struct {
    pub const Meta = struct {
        pub const name = "PushSubscription";
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
            .{ "endpoint", "get_endpoint", null },
            .{ "expirationTime", "get_expirationTime", null },
            .{ "options", "get_options", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getKey", "call_getKey", 1 },
            .{ "unsubscribe", "call_unsubscribe", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getKey",
            "unsubscribe",
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "endpoint", "get_endpoint", null },
            .{ "expirationTime", "get_expirationTime", null },
            .{ "options", "get_options", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            endpoint: runtime.USVString = undefined,
            expirationTime: ?typedefs.EpochTimeStamp = null,
            options: *runtime.Instance = undefined,
            cached_options: ?*runtime.Instance = null,
            _internal: ?*PushSubscriptionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_endpoint = &get_endpoint,
        .get_expirationTime = &get_expirationTime,
        .get_options = &get_options,

        .call_getKey = &call_getKey,
        .call_toJSON = &call_toJSON,
        .call_unsubscribe = &call_unsubscribe,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("PushSubscription has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(PushSubscriptionImpl, "init") and @hasDecl(PushSubscriptionImpl, "initOwn")) @compileError("PushSubscriptionImpl defines both init and initOwn");
        if (comptime @hasDecl(PushSubscriptionImpl, "init")) return PushSubscriptionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PushSubscriptionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PushSubscriptionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PushSubscriptionImpl, "init")) return false;
        if (comptime @hasDecl(PushSubscriptionImpl, "construction_args")) {
            inline for (PushSubscriptionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PushSubscriptionImpl, "deinit") and @hasDecl(PushSubscriptionImpl, "deinitOwn")) @compileError("PushSubscriptionImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(PushSubscriptionImpl, "deinit")) return PushSubscriptionImpl.deinit(instance);
        if (comptime @hasDecl(PushSubscriptionImpl, "deinitOwn")) PushSubscriptionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PushSubscription")) {
            if (comptime @hasDecl(impls.PushSubscription, "installHooks")) impls.PushSubscription.installHooks();
        }
    }

    pub fn get_endpoint(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PushSubscriptionImpl.get_endpoint(instance);
    }

    pub fn get_expirationTime(instance: *runtime.Instance) anyerror!?EpochTimeStamp {
        return try PushSubscriptionImpl.get_expirationTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_options(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_options) |cached| {
            return cached;
        }
        const value = try PushSubscriptionImpl.get_options(instance);
        state.own.cached_options = value;
        @import("dom").same_object_cache.made(instance, value, "options");
        return value;
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PushSubscriptionJSON {
        return try PushSubscriptionImpl.call_toJSON(instance);
    }

    pub fn call_unsubscribe(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PushSubscriptionImpl.call_unsubscribe(instance);
    }

    pub fn call_getKey(instance: *runtime.Instance, name: PushEncryptionKeyName) anyerror!?runtime.JSValue {
        return try PushSubscriptionImpl.call_getKey(instance, name);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_unsubscribe",
    };
};

//! Generated from: fedcm.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IdentityProviderImpl = @import("impls").IdentityProvider;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const IdentityResolveOptions = @import("dictionaries").IdentityResolveOptions;
const IdentityProviderConfig = @import("dictionaries").IdentityProviderConfig;

pub const IdentityProvider = struct {
    pub const Meta = struct {
        pub const name = "IdentityProvider";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "close", "call_static_close", 0 },
            .{ "resolve", "call_static_resolve", 1 },
            .{ "getUserInfo", "call_static_getUserInfo", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "resolve",
            "getUserInfo",
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
            _internal: ?*IdentityProviderImpl.InternalState = null,
        },
    );

    const delegates = .{
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
            if (comptime !takesConstructionArg(field_name)) @compileError("IdentityProvider has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(IdentityProviderImpl, "init") and @hasDecl(IdentityProviderImpl, "initOwn")) @compileError("IdentityProviderImpl defines both init and initOwn");
        if (comptime @hasDecl(IdentityProviderImpl, "init")) return IdentityProviderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(IdentityProviderImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try IdentityProviderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IdentityProviderImpl, "init")) return false;
        if (comptime @hasDecl(IdentityProviderImpl, "construction_args")) {
            inline for (IdentityProviderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IdentityProviderImpl, "deinit") and @hasDecl(IdentityProviderImpl, "deinitOwn")) @compileError("IdentityProviderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IdentityProviderImpl, "deinit")) return IdentityProviderImpl.deinit(instance);
        if (comptime @hasDecl(IdentityProviderImpl, "deinitOwn")) IdentityProviderImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IdentityProvider")) {
            if (comptime @hasDecl(impls.IdentityProvider, "installHooks")) impls.IdentityProvider.installHooks();
        }
    }

    pub fn call_static_getUserInfo(instance: *runtime.Instance, config: IdentityProviderConfig) anyerror!runtime.JSValue {
        return try IdentityProviderImpl.call_static_getUserInfo(instance, config);
    }

    pub fn call_static_resolve(instance: *runtime.Instance, token: runtime.JSValue, options: webidl.Opt(IdentityResolveOptions)) anyerror!runtime.JSValue {
        return try IdentityProviderImpl.call_static_resolve(instance, token, options);
    }

    pub fn call_static_close(instance: *runtime.Instance) anyerror!void {
        return try IdentityProviderImpl.call_static_close(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_getUserInfo",
        "call_static_resolve",
    };
};

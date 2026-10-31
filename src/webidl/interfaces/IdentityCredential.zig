//! Generated from: fedcm.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IdentityCredentialImpl = @import("impls").IdentityCredential;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Credential = @import("interfaces").Credential;
const IdentityCredentialDisconnectOptions = @import("dictionaries").IdentityCredentialDisconnectOptions;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const IdentityCredential = struct {
    pub const Meta = struct {
        pub const name = "IdentityCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "token", "get_token", null },
            .{ "isAutoSelected", "get_isAutoSelected", null },
            .{ "configURL", "get_configURL", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "disconnect", "call_static_disconnect", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "disconnect",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isConditionalMediationAvailable",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "token", "get_token", null },
            .{ "isAutoSelected", "get_isAutoSelected", null },
            .{ "configURL", "get_configURL", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            token: runtime.JSValue = undefined,
            isAutoSelected: bool = undefined,
            configURL: runtime.USVString = undefined,
            _internal: ?*IdentityCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_configURL = &get_configURL,
        .get_isAutoSelected = &get_isAutoSelected,
        .get_token = &get_token,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("IdentityCredential has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(IdentityCredentialImpl, "init") and @hasDecl(IdentityCredentialImpl, "initOwn")) @compileError("IdentityCredentialImpl defines both init and initOwn");
        if (comptime @hasDecl(IdentityCredentialImpl, "init")) return IdentityCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(IdentityCredentialImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try IdentityCredentialImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(IdentityCredentialImpl, "init")) return false;
        if (comptime @hasDecl(IdentityCredentialImpl, "construction_args")) {
            inline for (IdentityCredentialImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(IdentityCredentialImpl, "deinit") and @hasDecl(IdentityCredentialImpl, "deinitOwn")) @compileError("IdentityCredentialImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(IdentityCredentialImpl, "deinit")) return IdentityCredentialImpl.deinit(instance);
        if (comptime @hasDecl(IdentityCredentialImpl, "deinitOwn")) IdentityCredentialImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "IdentityCredential")) {
            if (comptime @hasDecl(impls.IdentityCredential, "installHooks")) impls.IdentityCredential.installHooks();
        }
    }

    pub fn get_token(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try IdentityCredentialImpl.get_token(instance);
    }

    pub fn get_isAutoSelected(instance: *runtime.Instance) anyerror!bool {
        return try IdentityCredentialImpl.get_isAutoSelected(instance);
    }

    pub fn get_configURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try IdentityCredentialImpl.get_configURL(instance);
    }

    pub fn call_static_disconnect(instance: *runtime.Instance, options: IdentityCredentialDisconnectOptions) anyerror!runtime.JSValue {
        return try IdentityCredentialImpl.call_static_disconnect(instance, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_disconnect",
    };
};

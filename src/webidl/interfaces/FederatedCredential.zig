//! Generated from: credential-management.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FederatedCredentialImpl = @import("impls").FederatedCredential;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Credential = @import("interfaces").Credential;
const CredentialUserData = @import("mixins").CredentialUserData;
const USVString = @import("typedefs").USVString;
const FederatedCredentialInit = @import("dictionaries").FederatedCredentialInit;
const DOMString = @import("typedefs").DOMString;

pub const FederatedCredential = struct {
    pub const Meta = struct {
        pub const name = "FederatedCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{
            CredentialUserData,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "provider", "get_provider", null },
            .{ "protocol", "get_protocol", null },
            .{ "name", "get_name", null },
            .{ "iconURL", "get_iconURL", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isConditionalMediationAvailable",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "provider", "get_provider", null },
            .{ "protocol", "get_protocol", null },
            .{ "name", "get_name", null },
            .{ "iconURL", "get_iconURL", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "name",
            "iconURL",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            provider: runtime.USVString = undefined,
            protocol: ?runtime.DOMString = null,
            name: runtime.USVString = undefined,
            iconURL: runtime.USVString = undefined,
            _internal: ?*FederatedCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_iconURL = &get_iconURL,
        .get_name = &get_name,
        .get_protocol = &get_protocol,
        .get_provider = &get_provider,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("FederatedCredential has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(FederatedCredentialImpl, "init") and @hasDecl(FederatedCredentialImpl, "initOwn")) @compileError("FederatedCredentialImpl defines both init and initOwn");
        if (comptime @hasDecl(FederatedCredentialImpl, "init")) return FederatedCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(FederatedCredentialImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try FederatedCredentialImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FederatedCredentialImpl, "init")) return false;
        if (comptime @hasDecl(FederatedCredentialImpl, "construction_args")) {
            inline for (FederatedCredentialImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FederatedCredentialImpl, "deinit") and @hasDecl(FederatedCredentialImpl, "deinitOwn")) @compileError("FederatedCredentialImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FederatedCredentialImpl, "deinit")) return FederatedCredentialImpl.deinit(instance);
        if (comptime @hasDecl(FederatedCredentialImpl, "deinitOwn")) FederatedCredentialImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FederatedCredential")) {
            if (comptime @hasDecl(impls.FederatedCredential, "installHooks")) impls.FederatedCredential.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, data: FederatedCredentialInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FederatedCredentialImpl.call_constructor(ctx, data);
    }

    pub fn get_provider(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FederatedCredentialImpl.get_provider(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try FederatedCredentialImpl.get_protocol(instance);
    }

    /// Extended attributes: [SecureContext]
    pub const get_name = mixins.CredentialUserData.get_name;

    /// Extended attributes: [SecureContext]
    pub const get_iconURL = mixins.CredentialUserData.get_iconURL;
};

//! Generated from: credential-management.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PasswordCredentialImpl = @import("impls").PasswordCredential;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Credential = @import("interfaces").Credential;
const CredentialUserData = @import("mixins").CredentialUserData;
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const PasswordCredentialData = @import("dictionaries").PasswordCredentialData;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const PasswordCredential = struct {
    pub const Meta = struct {
        pub const name = "PasswordCredential";
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
            .{ "password", "get_password", null },
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
            .{ "password", "get_password", null },
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
            password: runtime.USVString = undefined,
            name: runtime.USVString = undefined,
            iconURL: runtime.USVString = undefined,
            _internal: ?*PasswordCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_iconURL = &get_iconURL,
        .get_name = &get_name,
        .get_password = &get_password,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PasswordCredential has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PasswordCredentialImpl, "init") and @hasDecl(PasswordCredentialImpl, "initOwn")) @compileError("PasswordCredentialImpl defines both init and initOwn");
        if (comptime @hasDecl(PasswordCredentialImpl, "init")) return PasswordCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PasswordCredentialImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PasswordCredentialImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PasswordCredentialImpl, "init")) return false;
        if (comptime @hasDecl(PasswordCredentialImpl, "construction_args")) {
            inline for (PasswordCredentialImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PasswordCredentialImpl, "deinit") and @hasDecl(PasswordCredentialImpl, "deinitOwn")) @compileError("PasswordCredentialImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PasswordCredentialImpl, "deinit")) return PasswordCredentialImpl.deinit(instance);
        if (comptime @hasDecl(PasswordCredentialImpl, "deinitOwn")) PasswordCredentialImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PasswordCredential")) {
            if (comptime @hasDecl(impls.PasswordCredential, "installHooks")) impls.PasswordCredential.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(form)
        HTMLFormElement: *runtime.Instance,
        /// constructor(data)
        PasswordCredentialData: PasswordCredentialData,
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "HTMLFormElement", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "HTMLFormElement")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").HTMLFormElement.State) } else .other)} }} },
        .{ .function = "PasswordCredentialData", .args = &.{.{ .kinds = &.{.dictionary} }} },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try PasswordCredentialImpl.call_constructor(ctx, args);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "HTMLFormElement", 0, "HTMLFormElement" },
    };

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_password(instance);
    }

    /// Extended attributes: [SecureContext]
    pub const get_name = mixins.CredentialUserData.get_name;

    /// Extended attributes: [SecureContext]
    pub const get_iconURL = mixins.CredentialUserData.get_iconURL;
};

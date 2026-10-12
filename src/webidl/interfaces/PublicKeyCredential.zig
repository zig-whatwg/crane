//! Generated from: webauthn.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PublicKeyCredentialImpl = @import("impls").PublicKeyCredential;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Credential = @import("interfaces").Credential;
const PublicKeyCredentialRequestOptionsJSON = @import("dictionaries").PublicKeyCredentialRequestOptionsJSON;
const PublicKeyCredentialCreationOptionsJSON = @import("dictionaries").PublicKeyCredentialCreationOptionsJSON;
const AllAcceptedCredentialsOptions = @import("dictionaries").AllAcceptedCredentialsOptions;
const CurrentUserDetailsOptions = @import("dictionaries").CurrentUserDetailsOptions;
const AuthenticationExtensionsClientOutputs = @import("dictionaries").AuthenticationExtensionsClientOutputs;
const USVString = @import("typedefs").USVString;
const PublicKeyCredentialClientCapabilities = @import("typedefs").PublicKeyCredentialClientCapabilities;
const AuthenticatorResponse = @import("interfaces").AuthenticatorResponse;
const PublicKeyCredentialCreationOptions = @import("dictionaries").PublicKeyCredentialCreationOptions;
const PublicKeyCredentialRequestOptions = @import("dictionaries").PublicKeyCredentialRequestOptions;
const PublicKeyCredentialJSON = @import("typedefs").PublicKeyCredentialJSON;
const DOMString = @import("typedefs").DOMString;
const UnknownCredentialOptions = @import("dictionaries").UnknownCredentialOptions;

pub const PublicKeyCredential = struct {
    pub const Meta = struct {
        pub const name = "PublicKeyCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "rawId", "get_rawId", null },
            .{ "response", "get_response", null },
            .{ "authenticatorAttachment", "get_authenticatorAttachment", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getClientExtensionResults", "call_getClientExtensionResults", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isConditionalMediationAvailable", "call_static_isConditionalMediationAvailable", 0 },
            .{ "isUserVerifyingPlatformAuthenticatorAvailable", "call_static_isUserVerifyingPlatformAuthenticatorAvailable", 0 },
            .{ "getClientCapabilities", "call_static_getClientCapabilities", 0 },
            .{ "parseCreationOptionsFromJSON", "call_static_parseCreationOptionsFromJSON", 1 },
            .{ "parseRequestOptionsFromJSON", "call_static_parseRequestOptionsFromJSON", 1 },
            .{ "signalUnknownCredential", "call_static_signalUnknownCredential", 1 },
            .{ "signalAllAcceptedCredentials", "call_static_signalAllAcceptedCredentials", 1 },
            .{ "signalCurrentUserDetails", "call_static_signalCurrentUserDetails", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getClientExtensionResults",
            "isConditionalMediationAvailable",
            "toJSON",
            "isUserVerifyingPlatformAuthenticatorAvailable",
            "getClientCapabilities",
            "parseCreationOptionsFromJSON",
            "parseRequestOptionsFromJSON",
            "signalUnknownCredential",
            "signalAllAcceptedCredentials",
            "signalCurrentUserDetails",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "willRequestConditionalCreation",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "rawId", "get_rawId", null },
            .{ "response", "get_response", null },
            .{ "authenticatorAttachment", "get_authenticatorAttachment", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            rawId: runtime.ArrayBuffer = undefined,
            response: *runtime.Instance = undefined,
            authenticatorAttachment: ?typedefs.DOMString = null,
            cached_rawId: ?runtime.JSValue = null,
            cached_response: ?*runtime.Instance = null,
            _internal: ?*PublicKeyCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_authenticatorAttachment = &get_authenticatorAttachment,
        .get_rawId = &get_rawId,
        .get_response = &get_response,

        .call_getClientExtensionResults = &call_getClientExtensionResults,
        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("PublicKeyCredential has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PublicKeyCredentialImpl, "init") and @hasDecl(PublicKeyCredentialImpl, "initOwn")) @compileError("PublicKeyCredentialImpl defines both init and initOwn");
        if (comptime @hasDecl(PublicKeyCredentialImpl, "init")) return PublicKeyCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PublicKeyCredentialImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PublicKeyCredentialImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PublicKeyCredentialImpl, "init")) return false;
        if (comptime @hasDecl(PublicKeyCredentialImpl, "construction_args")) {
            inline for (PublicKeyCredentialImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PublicKeyCredentialImpl, "deinit") and @hasDecl(PublicKeyCredentialImpl, "deinitOwn")) @compileError("PublicKeyCredentialImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PublicKeyCredentialImpl, "deinit")) return PublicKeyCredentialImpl.deinit(instance);
        if (comptime @hasDecl(PublicKeyCredentialImpl, "deinitOwn")) PublicKeyCredentialImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PublicKeyCredential")) {
            if (comptime @hasDecl(impls.PublicKeyCredential, "installHooks")) impls.PublicKeyCredential.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_rawId(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.get_rawId(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_response(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_response) |cached| {
            return cached;
        }
        const value = try PublicKeyCredentialImpl.get_response(instance);
        state.own.cached_response = value;
        return value;
    }

    pub fn get_authenticatorAttachment(instance: *runtime.Instance) anyerror!?DOMString {
        return try PublicKeyCredentialImpl.get_authenticatorAttachment(instance);
    }

    pub fn call_static_isUserVerifyingPlatformAuthenticatorAvailable(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.call_static_isUserVerifyingPlatformAuthenticatorAvailable(instance);
    }

    pub fn call_static_parseCreationOptionsFromJSON(instance: *runtime.Instance, options: PublicKeyCredentialCreationOptionsJSON) anyerror!PublicKeyCredentialCreationOptions {
        return try PublicKeyCredentialImpl.call_static_parseCreationOptionsFromJSON(instance, options);
    }

    pub fn call_static_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.call_static_isConditionalMediationAvailable(instance);
    }

    pub fn call_static_signalAllAcceptedCredentials(instance: *runtime.Instance, options: AllAcceptedCredentialsOptions) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.call_static_signalAllAcceptedCredentials(instance, options);
    }

    pub fn call_static_signalUnknownCredential(instance: *runtime.Instance, options: UnknownCredentialOptions) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.call_static_signalUnknownCredential(instance, options);
    }

    pub fn call_static_signalCurrentUserDetails(instance: *runtime.Instance, options: CurrentUserDetailsOptions) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.call_static_signalCurrentUserDetails(instance, options);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PublicKeyCredentialJSON {
        return try PublicKeyCredentialImpl.call_toJSON(instance);
    }

    pub fn call_getClientExtensionResults(instance: *runtime.Instance) anyerror!AuthenticationExtensionsClientOutputs {
        return try PublicKeyCredentialImpl.call_getClientExtensionResults(instance);
    }

    pub fn call_static_parseRequestOptionsFromJSON(instance: *runtime.Instance, options: PublicKeyCredentialRequestOptionsJSON) anyerror!PublicKeyCredentialRequestOptions {
        return try PublicKeyCredentialImpl.call_static_parseRequestOptionsFromJSON(instance, options);
    }

    pub fn call_static_getClientCapabilities(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PublicKeyCredentialImpl.call_static_getClientCapabilities(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_isUserVerifyingPlatformAuthenticatorAvailable",
        "call_static_isConditionalMediationAvailable",
        "call_static_signalAllAcceptedCredentials",
        "call_static_signalUnknownCredential",
        "call_static_signalCurrentUserDetails",
        "call_static_getClientCapabilities",
    };
};

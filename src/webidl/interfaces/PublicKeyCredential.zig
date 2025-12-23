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
        pub const lazy_properties = .{
        };
        
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
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PublicKeyCredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PublicKeyCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PublicKeyCredentialImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_rawId(instance: *runtime.Instance) anyerror!runtime.JSValue {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_rawId) |cached| {
            return cached;
        }
        const value = try PublicKeyCredentialImpl.get_rawId(instance);
        state.own.cached_rawId = value;
        return value;
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

};

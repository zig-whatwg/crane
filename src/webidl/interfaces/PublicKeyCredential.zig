//! Generated from: webauthn.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PublicKeyCredentialImpl = @import("impls").PublicKeyCredential;
const Credential = @import("interfaces").Credential;
const PublicKeyCredentialRequestOptionsJSON = @import("dictionaries").PublicKeyCredentialRequestOptionsJSON;
const PublicKeyCredentialCreationOptionsJSON = @import("dictionaries").PublicKeyCredentialCreationOptionsJSON;
const AllAcceptedCredentialsOptions = @import("dictionaries").AllAcceptedCredentialsOptions;
const CurrentUserDetailsOptions = @import("dictionaries").CurrentUserDetailsOptions;
const AuthenticationExtensionsClientOutputs = @import("dictionaries").AuthenticationExtensionsClientOutputs;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const AuthenticatorResponse = @import("interfaces").AuthenticatorResponse;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const PublicKeyCredentialCreationOptions = @import("dictionaries").PublicKeyCredentialCreationOptions;
const PublicKeyCredentialRequestOptions = @import("dictionaries").PublicKeyCredentialRequestOptions;
const Promise<PublicKeyCredentialClientCapabilities> = @import("interfaces").Promise<PublicKeyCredentialClientCapabilities>;
const PublicKeyCredentialJSON = @import("typedefs").PublicKeyCredentialJSON;
const DOMString = @import("typedefs").DOMString;
const UnknownCredentialOptions = @import("dictionaries").UnknownCredentialOptions;

pub const PublicKeyCredential = struct {
    pub const Meta = struct {
        pub const name = "PublicKeyCredential";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Credential;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            rawId: ArrayBuffer = undefined,
            response: AuthenticatorResponse = undefined,
            authenticatorAttachment: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PublicKeyCredential, .{
        .deinit_fn = &deinit_wrapper,

        .get_authenticatorAttachment = &get_authenticatorAttachment,
        .get_id = &get_id,
        .get_rawId = &get_rawId,
        .get_response = &get_response,
        .get_type = &get_type,

        .call_getClientCapabilities = &call_getClientCapabilities,
        .call_getClientExtensionResults = &call_getClientExtensionResults,
        .call_isConditionalMediationAvailable = &call_isConditionalMediationAvailable,
        .call_isUserVerifyingPlatformAuthenticatorAvailable = &call_isUserVerifyingPlatformAuthenticatorAvailable,
        .call_parseCreationOptionsFromJSON = &call_parseCreationOptionsFromJSON,
        .call_parseRequestOptionsFromJSON = &call_parseRequestOptionsFromJSON,
        .call_signalAllAcceptedCredentials = &call_signalAllAcceptedCredentials,
        .call_signalCurrentUserDetails = &call_signalCurrentUserDetails,
        .call_signalUnknownCredential = &call_signalUnknownCredential,
        .call_toJSON = &call_toJSON,
        .call_willRequestConditionalCreation = &call_willRequestConditionalCreation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PublicKeyCredentialImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PublicKeyCredentialImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PublicKeyCredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try PublicKeyCredentialImpl.get_type(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_rawId(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_rawId) |cached| {
            return cached;
        }
        const value = try PublicKeyCredentialImpl.get_rawId(instance);
        state.cached_rawId = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_response(instance: *runtime.Instance) anyerror!AuthenticatorResponse {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_response) |cached| {
            return cached;
        }
        const value = try PublicKeyCredentialImpl.get_response(instance);
        state.cached_response = value;
        return value;
    }

    pub fn get_authenticatorAttachment(instance: *runtime.Instance) anyerror!anyopaque {
        return try PublicKeyCredentialImpl.get_authenticatorAttachment(instance);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!anyopaque {
        return try PublicKeyCredentialImpl.call_willRequestConditionalCreation(instance);
    }

    pub fn call_isUserVerifyingPlatformAuthenticatorAvailable(instance: *runtime.Instance) anyerror!anyopaque {
        return try PublicKeyCredentialImpl.call_isUserVerifyingPlatformAuthenticatorAvailable(instance);
    }

    pub fn call_parseCreationOptionsFromJSON(instance: *runtime.Instance, options: PublicKeyCredentialCreationOptionsJSON) anyerror!PublicKeyCredentialCreationOptions {
        
        return try PublicKeyCredentialImpl.call_parseCreationOptionsFromJSON(instance, options);
    }

    pub fn call_signalUnknownCredential(instance: *runtime.Instance, options: UnknownCredentialOptions) anyerror!anyopaque {
        
        return try PublicKeyCredentialImpl.call_signalUnknownCredential(instance, options);
    }

    pub fn call_signalCurrentUserDetails(instance: *runtime.Instance, options: CurrentUserDetailsOptions) anyerror!anyopaque {
        
        return try PublicKeyCredentialImpl.call_signalCurrentUserDetails(instance, options);
    }

    pub fn call_parseRequestOptionsFromJSON(instance: *runtime.Instance, options: PublicKeyCredentialRequestOptionsJSON) anyerror!PublicKeyCredentialRequestOptions {
        
        return try PublicKeyCredentialImpl.call_parseRequestOptionsFromJSON(instance, options);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PublicKeyCredentialJSON {
        return try PublicKeyCredentialImpl.call_toJSON(instance);
    }

    pub fn call_getClientCapabilities(instance: *runtime.Instance) anyerror!anyopaque {
        return try PublicKeyCredentialImpl.call_getClientCapabilities(instance);
    }

    pub fn call_getClientExtensionResults(instance: *runtime.Instance) anyerror!AuthenticationExtensionsClientOutputs {
        return try PublicKeyCredentialImpl.call_getClientExtensionResults(instance);
    }

    pub fn call_signalAllAcceptedCredentials(instance: *runtime.Instance, options: AllAcceptedCredentialsOptions) anyerror!anyopaque {
        
        return try PublicKeyCredentialImpl.call_signalAllAcceptedCredentials(instance, options);
    }

    /// Arguments for isConditionalMediationAvailable (WebIDL overloading)
    pub const IsConditionalMediationAvailableArgs = union(enum) {
        /// isConditionalMediationAvailable()
        no_params: void,
        /// isConditionalMediationAvailable()
        no_params: void,
    };

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance, args: IsConditionalMediationAvailableArgs) anyerror!anyopaque {
        switch (args) {
            .no_params => return try PublicKeyCredentialImpl.no_params(instance),
            .no_params => return try PublicKeyCredentialImpl.no_params(instance),
        }
    }

};

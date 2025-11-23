//! Implementation for PublicKeyCredential interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const PublicKeyCredential = interfaces.PublicKeyCredential;

pub const State = PublicKeyCredential.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for rawId
pub fn get_rawId(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for response
pub fn get_response(instance: *runtime.Instance) ImplError!interfaces.AuthenticatorResponse {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for authenticatorAttachment
pub fn get_authenticatorAttachment(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isUserVerifyingPlatformAuthenticatorAvailable
pub fn call_isUserVerifyingPlatformAuthenticatorAvailable(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isConditionalMediationAvailable
pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: signalUnknownCredential
pub fn call_signalUnknownCredential(instance: *runtime.Instance, options: dictionaries.UnknownCredentialOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: signalCurrentUserDetails
pub fn call_signalCurrentUserDetails(instance: *runtime.Instance, options: dictionaries.CurrentUserDetailsOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: parseRequestOptionsFromJSON
pub fn call_parseRequestOptionsFromJSON(instance: *runtime.Instance, options: dictionaries.PublicKeyCredentialRequestOptionsJSON) ImplError!dictionaries.PublicKeyCredentialRequestOptions {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!typedefs.PublicKeyCredentialJSON {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getClientCapabilities
pub fn call_getClientCapabilities(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getClientExtensionResults
pub fn call_getClientExtensionResults(instance: *runtime.Instance) ImplError!dictionaries.AuthenticationExtensionsClientOutputs {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: signalAllAcceptedCredentials
pub fn call_signalAllAcceptedCredentials(instance: *runtime.Instance, options: dictionaries.AllAcceptedCredentialsOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: parseCreationOptionsFromJSON
pub fn call_parseCreationOptionsFromJSON(instance: *runtime.Instance, options: dictionaries.PublicKeyCredentialCreationOptionsJSON) ImplError!dictionaries.PublicKeyCredentialCreationOptions {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}


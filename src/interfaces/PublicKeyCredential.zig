//! Generated from: webauthn.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PublicKeyCredentialImpl = @import("../impls/PublicKeyCredential.zig");
const Credential = @import("Credential.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PublicKeyCredentialImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PublicKeyCredentialImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.get_id(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.get_type(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_rawId(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_rawId) |cached| {
            return cached;
        }
        const value = PublicKeyCredentialImpl.get_rawId(state);
        state.cached_rawId = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_response(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_response) |cached| {
            return cached;
        }
        const value = PublicKeyCredentialImpl.get_response(state);
        state.cached_response = value;
        return value;
    }

    pub fn get_authenticatorAttachment(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.get_authenticatorAttachment(state);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.call_willRequestConditionalCreation(state);
    }

    pub fn call_isUserVerifyingPlatformAuthenticatorAvailable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.call_isUserVerifyingPlatformAuthenticatorAvailable(state);
    }

    pub fn call_parseCreationOptionsFromJSON(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PublicKeyCredentialImpl.call_parseCreationOptionsFromJSON(state, options);
    }

    pub fn call_signalUnknownCredential(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PublicKeyCredentialImpl.call_signalUnknownCredential(state, options);
    }

    pub fn call_signalCurrentUserDetails(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PublicKeyCredentialImpl.call_signalCurrentUserDetails(state, options);
    }

    pub fn call_parseRequestOptionsFromJSON(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PublicKeyCredentialImpl.call_parseRequestOptionsFromJSON(state, options);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.call_toJSON(state);
    }

    pub fn call_getClientCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.call_getClientCapabilities(state);
    }

    pub fn call_getClientExtensionResults(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PublicKeyCredentialImpl.call_getClientExtensionResults(state);
    }

    pub fn call_signalAllAcceptedCredentials(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PublicKeyCredentialImpl.call_signalAllAcceptedCredentials(state, options);
    }

    /// Arguments for isConditionalMediationAvailable (WebIDL overloading)
    pub const IsConditionalMediationAvailableArgs = union(enum) {
        /// isConditionalMediationAvailable()
        no_params: void,
        /// isConditionalMediationAvailable()
        no_params: void,
    };

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance, args: IsConditionalMediationAvailableArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return PublicKeyCredentialImpl.no_params(state),
            .no_params => return PublicKeyCredentialImpl.no_params(state),
        }
    }

};

//! Generated from: webauthn.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AuthenticatorAttestationResponseImpl = @import("../impls/AuthenticatorAttestationResponse.zig");
const AuthenticatorResponse = @import("AuthenticatorResponse.zig");

pub const AuthenticatorAttestationResponse = struct {
    pub const Meta = struct {
        pub const name = "AuthenticatorAttestationResponse";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AuthenticatorResponse;
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
            attestationObject: ArrayBuffer = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AuthenticatorAttestationResponse, .{
        .deinit_fn = &deinit_wrapper,

        .get_attestationObject = &get_attestationObject,
        .get_clientDataJSON = &get_clientDataJSON,

        .call_getAuthenticatorData = &call_getAuthenticatorData,
        .call_getPublicKey = &call_getPublicKey,
        .call_getPublicKeyAlgorithm = &call_getPublicKeyAlgorithm,
        .call_getTransports = &call_getTransports,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AuthenticatorAttestationResponseImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AuthenticatorAttestationResponseImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_clientDataJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clientDataJSON) |cached| {
            return cached;
        }
        const value = AuthenticatorAttestationResponseImpl.get_clientDataJSON(state);
        state.cached_clientDataJSON = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_attestationObject(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attestationObject) |cached| {
            return cached;
        }
        const value = AuthenticatorAttestationResponseImpl.get_attestationObject(state);
        state.cached_attestationObject = value;
        return value;
    }

    pub fn call_getPublicKey(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AuthenticatorAttestationResponseImpl.call_getPublicKey(state);
    }

    pub fn call_getTransports(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AuthenticatorAttestationResponseImpl.call_getTransports(state);
    }

    pub fn call_getPublicKeyAlgorithm(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AuthenticatorAttestationResponseImpl.call_getPublicKeyAlgorithm(state);
    }

    pub fn call_getAuthenticatorData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AuthenticatorAttestationResponseImpl.call_getAuthenticatorData(state);
    }

};

//! Generated from: webauthn.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AuthenticatorAttestationResponseImpl = @import("impls").AuthenticatorAttestationResponse;
const AuthenticatorResponse = @import("interfaces").AuthenticatorResponse;
const COSEAlgorithmIdentifier = @import("typedefs").COSEAlgorithmIdentifier;
const ArrayBuffer = @import("interfaces").ArrayBuffer;

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
        
        // Initialize the instance (Impl receives full instance)
        AuthenticatorAttestationResponseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AuthenticatorAttestationResponseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_clientDataJSON(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_clientDataJSON) |cached| {
            return cached;
        }
        const value = try AuthenticatorAttestationResponseImpl.get_clientDataJSON(instance);
        state.cached_clientDataJSON = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_attestationObject(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attestationObject) |cached| {
            return cached;
        }
        const value = try AuthenticatorAttestationResponseImpl.get_attestationObject(instance);
        state.cached_attestationObject = value;
        return value;
    }

    pub fn call_getPublicKey(instance: *runtime.Instance) anyerror!anyopaque {
        return try AuthenticatorAttestationResponseImpl.call_getPublicKey(instance);
    }

    pub fn call_getTransports(instance: *runtime.Instance) anyerror!anyopaque {
        return try AuthenticatorAttestationResponseImpl.call_getTransports(instance);
    }

    pub fn call_getPublicKeyAlgorithm(instance: *runtime.Instance) anyerror!COSEAlgorithmIdentifier {
        return try AuthenticatorAttestationResponseImpl.call_getPublicKeyAlgorithm(instance);
    }

    pub fn call_getAuthenticatorData(instance: *runtime.Instance) anyerror!anyopaque {
        return try AuthenticatorAttestationResponseImpl.call_getAuthenticatorData(instance);
    }

};

//! Generated from: webauthn.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AuthenticatorAttestationResponseImpl = @import("impls").AuthenticatorAttestationResponse;
const AuthenticatorResponse = @import("interfaces").AuthenticatorResponse;
const COSEAlgorithmIdentifier = @import("typedefs").COSEAlgorithmIdentifier;
const DOMString = @import("typedefs").DOMString;

pub const AuthenticatorAttestationResponse = struct {
    pub const Meta = struct {
        pub const name = "AuthenticatorAttestationResponse";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AuthenticatorResponse;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "attestationObject", "get_attestationObject", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getTransports", "call_getTransports", 0 },
            .{ "getAuthenticatorData", "call_getAuthenticatorData", 0 },
            .{ "getPublicKey", "call_getPublicKey", 0 },
            .{ "getPublicKeyAlgorithm", "call_getPublicKeyAlgorithm", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTransports",
            "getAuthenticatorData",
            "getPublicKey",
            "getPublicKeyAlgorithm",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "attestationObject", "get_attestationObject", null },
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
            attestationObject: runtime.ArrayBuffer = undefined,
            cached_attestationObject: ?runtime.ArrayBuffer = null,
        },
    );

    const delegates = .{

        .get_attestationObject = &get_attestationObject,

        .call_getAuthenticatorData = &call_getAuthenticatorData,
        .call_getPublicKey = &call_getPublicKey,
        .call_getPublicKeyAlgorithm = &call_getPublicKeyAlgorithm,
        .call_getTransports = &call_getTransports,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AuthenticatorAttestationResponseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AuthenticatorAttestationResponseImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attestationObject(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_attestationObject) |cached| {
            return cached;
        }
        const value = try AuthenticatorAttestationResponseImpl.get_attestationObject(instance);
        state.own.cached_attestationObject = value;
        return value;
    }

    pub fn call_getPublicKey(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AuthenticatorAttestationResponseImpl.call_getPublicKey(instance);
    }

    pub fn call_getTransports(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AuthenticatorAttestationResponseImpl.call_getTransports(instance);
    }

    pub fn call_getPublicKeyAlgorithm(instance: *runtime.Instance) anyerror!COSEAlgorithmIdentifier {
        return try AuthenticatorAttestationResponseImpl.call_getPublicKeyAlgorithm(instance);
    }

    pub fn call_getAuthenticatorData(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AuthenticatorAttestationResponseImpl.call_getAuthenticatorData(instance);
    }

};

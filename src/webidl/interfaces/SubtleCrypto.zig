//! Generated from: webcrypto.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SubtleCryptoImpl = @import("impls").SubtleCrypto;
const EncapsulatedBits = @import("dictionaries").EncapsulatedBits;
const AlgorithmIdentifier = @import("typedefs").AlgorithmIdentifier;
const KeyUsage = @import("enums").KeyUsage;
const KeyFormat = @import("enums").KeyFormat;
const BufferSource = @import("typedefs").BufferSource;
const JsonWebKey = @import("dictionaries").JsonWebKey;
const EncapsulatedKey = @import("dictionaries").EncapsulatedKey;
const DOMString = @import("typedefs").DOMString;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SubtleCrypto = struct {
    pub const Meta = struct {
        pub const name = "SubtleCrypto";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "encrypt", "call_encrypt", 3 },
            .{ "decrypt", "call_decrypt", 3 },
            .{ "sign", "call_sign", 3 },
            .{ "verify", "call_verify", 4 },
            .{ "digest", "call_digest", 2 },
            .{ "generateKey", "call_generateKey", 3 },
            .{ "deriveKey", "call_deriveKey", 5 },
            .{ "deriveBits", "call_deriveBits", 2 },
            .{ "importKey", "call_importKey", 5 },
            .{ "exportKey", "call_exportKey", 2 },
            .{ "wrapKey", "call_wrapKey", 4 },
            .{ "unwrapKey", "call_unwrapKey", 7 },
            .{ "encapsulateKey", "call_encapsulateKey", 5 },
            .{ "encapsulateBits", "call_encapsulateBits", 2 },
            .{ "decapsulateKey", "call_decapsulateKey", 6 },
            .{ "decapsulateBits", "call_decapsulateBits", 3 },
            .{ "getPublicKey", "call_getPublicKey", 2 },
            .{ "supports", "call_supports", 2 },
            .{ "supports", "call_supports", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "encrypt",
            "decrypt",
            "sign",
            "verify",
            "digest",
            "generateKey",
            "deriveKey",
            "deriveBits",
            "importKey",
            "exportKey",
            "wrapKey",
            "unwrapKey",
            "encapsulateKey",
            "encapsulateBits",
            "decapsulateKey",
            "decapsulateBits",
            "getPublicKey",
            "supports",
            "supports",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_decapsulateBits = &call_decapsulateBits,
        .call_decapsulateKey = &call_decapsulateKey,
        .call_decrypt = &call_decrypt,
        .call_deriveBits = &call_deriveBits,
        .call_deriveKey = &call_deriveKey,
        .call_digest = &call_digest,
        .call_encapsulateBits = &call_encapsulateBits,
        .call_encapsulateKey = &call_encapsulateKey,
        .call_encrypt = &call_encrypt,
        .call_exportKey = &call_exportKey,
        .call_generateKey = &call_generateKey,
        .call_getPublicKey = &call_getPublicKey,
        .call_importKey = &call_importKey,
        .call_sign = &call_sign,
        .call_supports = &call_supports,
        .call_unwrapKey = &call_unwrapKey,
        .call_verify = &call_verify,
        .call_wrapKey = &call_wrapKey,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SubtleCryptoImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SubtleCryptoImpl.deinit(instance);
    }

    pub fn call_generateKey(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_generateKey(instance, algorithm, extractable, keyUsages);
    }

    pub fn call_exportKey(instance: *runtime.Instance, format: KeyFormat, key: CryptoKey) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_exportKey(instance, format, key);
    }

    pub fn call_sign(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, data: BufferSource) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_sign(instance, algorithm, key, data);
    }

    pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: AlgorithmIdentifier, encapsulationKey: CryptoKey) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_encapsulateBits(instance, encapsulationAlgorithm, encapsulationKey);
    }

    pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: AlgorithmIdentifier, decapsulationKey: CryptoKey, ciphertext: BufferSource, sharedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_decapsulateKey(instance, decapsulationAlgorithm, decapsulationKey, ciphertext, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_deriveBits(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, baseKey: CryptoKey, length: u32) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_deriveBits(instance, algorithm, baseKey, length);
    }

    pub fn call_getPublicKey(instance: *runtime.Instance, key: CryptoKey, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_getPublicKey(instance, key, keyUsages);
    }

    pub fn call_deriveKey(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, baseKey: CryptoKey, derivedKeyType: AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_deriveKey(instance, algorithm, baseKey, derivedKeyType, extractable, keyUsages);
    }

    pub fn call_verify(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, signature: BufferSource, data: BufferSource) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_verify(instance, algorithm, key, signature, data);
    }

    pub fn call_supports(instance: *runtime.Instance, operation: DOMString, algorithm: AlgorithmIdentifier, length: u32) anyerror!bool {
        
        return try SubtleCryptoImpl.call_supports(instance, operation, algorithm, length);
    }

    pub fn call_digest(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, data: BufferSource) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_digest(instance, algorithm, data);
    }

    pub fn call_importKey(instance: *runtime.Instance, format: KeyFormat, keyData: *const anyopaque, algorithm: AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_importKey(instance, format, keyData, algorithm, extractable, keyUsages);
    }

    pub fn call_wrapKey(instance: *runtime.Instance, format: KeyFormat, key: CryptoKey, wrappingKey: CryptoKey, wrapAlgorithm: AlgorithmIdentifier) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_wrapKey(instance, format, key, wrappingKey, wrapAlgorithm);
    }

    pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: AlgorithmIdentifier, decapsulationKey: CryptoKey, ciphertext: BufferSource) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_decapsulateBits(instance, decapsulationAlgorithm, decapsulationKey, ciphertext);
    }

    pub fn call_unwrapKey(instance: *runtime.Instance, format: KeyFormat, wrappedKey: BufferSource, unwrappingKey: CryptoKey, unwrapAlgorithm: AlgorithmIdentifier, unwrappedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_unwrapKey(instance, format, wrappedKey, unwrappingKey, unwrapAlgorithm, unwrappedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: AlgorithmIdentifier, encapsulationKey: CryptoKey, sharedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_encapsulateKey(instance, encapsulationAlgorithm, encapsulationKey, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_decrypt(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, data: BufferSource) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_decrypt(instance, algorithm, key, data);
    }

    pub fn call_encrypt(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, data: BufferSource) anyerror!*const anyopaque {
        
        return try SubtleCryptoImpl.call_encrypt(instance, algorithm, key, data);
    }

};

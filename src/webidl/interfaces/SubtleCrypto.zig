//! Generated from: webcrypto.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SubtleCryptoImpl = @import("impls").SubtleCrypto;
const CryptoKey = @import("interfaces").CryptoKey;
const Promise<(ArrayBufferorJsonWebKey)> = @import("interfaces").Promise<(ArrayBufferorJsonWebKey)>;
const (BufferSource or JsonWebKey) = @import("interfaces").(BufferSource or JsonWebKey);
const Promise<(CryptoKeyorCryptoKeyPair)> = @import("interfaces").Promise<(CryptoKeyorCryptoKeyPair)>;
const AlgorithmIdentifier = @import("typedefs").AlgorithmIdentifier;
const Promise<EncapsulatedBits> = @import("interfaces").Promise<EncapsulatedBits>;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const KeyFormat = @import("enums").KeyFormat;
const Promise<EncapsulatedKey> = @import("interfaces").Promise<EncapsulatedKey>;
const BufferSource = @import("typedefs").BufferSource;
const unsigned long = @import("interfaces").unsigned long;
const Promise<CryptoKey> = @import("interfaces").Promise<CryptoKey>;

pub const SubtleCrypto = struct {
    pub const Meta = struct {
        pub const name = "SubtleCrypto";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SubtleCrypto, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SubtleCryptoImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SubtleCryptoImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_generateKey(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, extractable: bool, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_generateKey(instance, algorithm, extractable, keyUsages);
    }

    pub fn call_exportKey(instance: *runtime.Instance, format: KeyFormat, key: CryptoKey) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_exportKey(instance, format, key);
    }

    pub fn call_sign(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, data: BufferSource) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_sign(instance, algorithm, key, data);
    }

    pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: AlgorithmIdentifier, encapsulationKey: CryptoKey) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_encapsulateBits(instance, encapsulationAlgorithm, encapsulationKey);
    }

    pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: AlgorithmIdentifier, decapsulationKey: CryptoKey, ciphertext: BufferSource, sharedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_decapsulateKey(instance, decapsulationAlgorithm, decapsulationKey, ciphertext, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_deriveBits(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, baseKey: CryptoKey, length: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_deriveBits(instance, algorithm, baseKey, length);
    }

    pub fn call_getPublicKey(instance: *runtime.Instance, key: CryptoKey, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_getPublicKey(instance, key, keyUsages);
    }

    pub fn call_deriveKey(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, baseKey: CryptoKey, derivedKeyType: AlgorithmIdentifier, extractable: bool, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_deriveKey(instance, algorithm, baseKey, derivedKeyType, extractable, keyUsages);
    }

    pub fn call_verify(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, signature: BufferSource, data: BufferSource) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_verify(instance, algorithm, key, signature, data);
    }

    /// Arguments for supports (WebIDL overloading)
    pub const SupportsArgs = union(enum) {
        /// supports(operation, algorithm, length)
        string_AlgorithmIdentifier_long?: struct {
            operation: DOMString,
            algorithm: AlgorithmIdentifier,
            length: anyopaque,
        },
        /// supports(operation, algorithm, additionalAlgorithm)
        string_AlgorithmIdentifier_AlgorithmIdentifier: struct {
            operation: DOMString,
            algorithm: AlgorithmIdentifier,
            additionalAlgorithm: AlgorithmIdentifier,
        },
    };

    pub fn call_supports(instance: *runtime.Instance, args: SupportsArgs) anyerror!bool {
        switch (args) {
            .string_AlgorithmIdentifier_long? => |a| return try SubtleCryptoImpl.string_AlgorithmIdentifier_long?(instance, a.operation, a.algorithm, a.length),
            .string_AlgorithmIdentifier_AlgorithmIdentifier => |a| return try SubtleCryptoImpl.string_AlgorithmIdentifier_AlgorithmIdentifier(instance, a.operation, a.algorithm, a.additionalAlgorithm),
        }
    }

    pub fn call_digest(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, data: BufferSource) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_digest(instance, algorithm, data);
    }

    pub fn call_importKey(instance: *runtime.Instance, format: KeyFormat, keyData: anyopaque, algorithm: AlgorithmIdentifier, extractable: bool, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_importKey(instance, format, keyData, algorithm, extractable, keyUsages);
    }

    pub fn call_wrapKey(instance: *runtime.Instance, format: KeyFormat, key: CryptoKey, wrappingKey: CryptoKey, wrapAlgorithm: AlgorithmIdentifier) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_wrapKey(instance, format, key, wrappingKey, wrapAlgorithm);
    }

    pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: AlgorithmIdentifier, decapsulationKey: CryptoKey, ciphertext: BufferSource) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_decapsulateBits(instance, decapsulationAlgorithm, decapsulationKey, ciphertext);
    }

    pub fn call_unwrapKey(instance: *runtime.Instance, format: KeyFormat, wrappedKey: BufferSource, unwrappingKey: CryptoKey, unwrapAlgorithm: AlgorithmIdentifier, unwrappedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_unwrapKey(instance, format, wrappedKey, unwrappingKey, unwrapAlgorithm, unwrappedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: AlgorithmIdentifier, encapsulationKey: CryptoKey, sharedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: anyopaque) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_encapsulateKey(instance, encapsulationAlgorithm, encapsulationKey, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_decrypt(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, data: BufferSource) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_decrypt(instance, algorithm, key, data);
    }

    pub fn call_encrypt(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: CryptoKey, data: BufferSource) anyerror!anyopaque {
        
        return try SubtleCryptoImpl.call_encrypt(instance, algorithm, key, data);
    }

};

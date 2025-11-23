//! Implementation for SubtleCrypto interface
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
const SubtleCrypto = interfaces.SubtleCrypto;

pub const State = SubtleCrypto.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Operation: generateKey
pub fn call_generateKey(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: exportKey
pub fn call_exportKey(instance: *runtime.Instance, format: enums.KeyFormat, key: interfaces.CryptoKey) ImplError!*const anyopaque {
    _ = instance;
    _ = format;
    _ = key;
    return error.NotImplemented;
}

/// Operation: sign
pub fn call_sign(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: interfaces.CryptoKey, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = data;
    return error.NotImplemented;
}

/// Operation: encapsulateBits
pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: typedefs.AlgorithmIdentifier, encapsulationKey: interfaces.CryptoKey) ImplError!*const anyopaque {
    _ = instance;
    _ = encapsulationAlgorithm;
    _ = encapsulationKey;
    return error.NotImplemented;
}

/// Operation: decapsulateKey
pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: typedefs.AlgorithmIdentifier, decapsulationKey: interfaces.CryptoKey, ciphertext: typedefs.BufferSource, sharedKeyAlgorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = decapsulationAlgorithm;
    _ = decapsulationKey;
    _ = ciphertext;
    _ = sharedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: deriveBits
pub fn call_deriveBits(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, baseKey: interfaces.CryptoKey, length: u32) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = baseKey;
    _ = length;
    return error.NotImplemented;
}

/// Operation: getPublicKey
pub fn call_getPublicKey(instance: *runtime.Instance, key: interfaces.CryptoKey, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = key;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: deriveKey
pub fn call_deriveKey(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, baseKey: interfaces.CryptoKey, derivedKeyType: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = baseKey;
    _ = derivedKeyType;
    _ = extractable;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: verify
pub fn call_verify(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: interfaces.CryptoKey, signature: typedefs.BufferSource, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = signature;
    _ = data;
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, operation: runtime.DOMString, algorithm: typedefs.AlgorithmIdentifier, length: u32) ImplError!bool {
    _ = instance;
    _ = operation;
    _ = algorithm;
    _ = length;
    return error.NotImplemented;
}

/// Operation: digest
pub fn call_digest(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = data;
    return error.NotImplemented;
}

/// Operation: importKey
pub fn call_importKey(instance: *runtime.Instance, format: enums.KeyFormat, keyData: *const anyopaque, algorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = format;
    _ = keyData;
    _ = algorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: wrapKey
pub fn call_wrapKey(instance: *runtime.Instance, format: enums.KeyFormat, key: interfaces.CryptoKey, wrappingKey: interfaces.CryptoKey, wrapAlgorithm: typedefs.AlgorithmIdentifier) ImplError!*const anyopaque {
    _ = instance;
    _ = format;
    _ = key;
    _ = wrappingKey;
    _ = wrapAlgorithm;
    return error.NotImplemented;
}

/// Operation: decapsulateBits
pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: typedefs.AlgorithmIdentifier, decapsulationKey: interfaces.CryptoKey, ciphertext: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = decapsulationAlgorithm;
    _ = decapsulationKey;
    _ = ciphertext;
    return error.NotImplemented;
}

/// Operation: unwrapKey
pub fn call_unwrapKey(instance: *runtime.Instance, format: enums.KeyFormat, wrappedKey: typedefs.BufferSource, unwrappingKey: interfaces.CryptoKey, unwrapAlgorithm: typedefs.AlgorithmIdentifier, unwrappedKeyAlgorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = format;
    _ = wrappedKey;
    _ = unwrappingKey;
    _ = unwrapAlgorithm;
    _ = unwrappedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: encapsulateKey
pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: typedefs.AlgorithmIdentifier, encapsulationKey: interfaces.CryptoKey, sharedKeyAlgorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = encapsulationAlgorithm;
    _ = encapsulationKey;
    _ = sharedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotImplemented;
}

/// Operation: decrypt
pub fn call_decrypt(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: interfaces.CryptoKey, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = data;
    return error.NotImplemented;
}

/// Operation: encrypt
pub fn call_encrypt(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: interfaces.CryptoKey, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = data;
    return error.NotImplemented;
}


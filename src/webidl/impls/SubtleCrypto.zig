//! Implementation for SubtleCrypto interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SubtleCrypto = @import("interfaces").SubtleCrypto;

pub const State = SubtleCrypto.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Operation: encrypt
pub fn call_encrypt(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: decrypt
pub fn call_decrypt(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: sign
pub fn call_sign(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: verify
pub fn call_verify(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, signature: anyopaque, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = key;
    _ = signature;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: digest
pub fn call_digest(instance: *runtime.Instance, algorithm: anyopaque, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: generateKey
pub fn call_generateKey(instance: *runtime.Instance, algorithm: anyopaque, extractable: bool, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = extractable;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deriveKey
pub fn call_deriveKey(instance: *runtime.Instance, algorithm: anyopaque, baseKey: anyopaque, derivedKeyType: anyopaque, extractable: bool, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = baseKey;
    _ = derivedKeyType;
    _ = extractable;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deriveBits
pub fn call_deriveBits(instance: *runtime.Instance, algorithm: anyopaque, baseKey: anyopaque, length: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = algorithm;
    _ = baseKey;
    _ = length;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: importKey
pub fn call_importKey(instance: *runtime.Instance, format: anyopaque, keyData: anyopaque, algorithm: anyopaque, extractable: bool, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = format;
    _ = keyData;
    _ = algorithm;
    _ = extractable;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: exportKey
pub fn call_exportKey(instance: *runtime.Instance, format: anyopaque, key: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = format;
    _ = key;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: wrapKey
pub fn call_wrapKey(instance: *runtime.Instance, format: anyopaque, key: anyopaque, wrappingKey: anyopaque, wrapAlgorithm: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = format;
    _ = key;
    _ = wrappingKey;
    _ = wrapAlgorithm;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unwrapKey
pub fn call_unwrapKey(instance: *runtime.Instance, format: anyopaque, wrappedKey: anyopaque, unwrappingKey: anyopaque, unwrapAlgorithm: anyopaque, unwrappedKeyAlgorithm: anyopaque, extractable: bool, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = format;
    _ = wrappedKey;
    _ = unwrappingKey;
    _ = unwrapAlgorithm;
    _ = unwrappedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: encapsulateKey
pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: anyopaque, encapsulationKey: anyopaque, sharedKeyAlgorithm: anyopaque, extractable: bool, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = encapsulationAlgorithm;
    _ = encapsulationKey;
    _ = sharedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: encapsulateBits
pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: anyopaque, encapsulationKey: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = encapsulationAlgorithm;
    _ = encapsulationKey;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: decapsulateKey
pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: anyopaque, decapsulationKey: anyopaque, ciphertext: anyopaque, sharedKeyAlgorithm: anyopaque, extractable: bool, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = decapsulationAlgorithm;
    _ = decapsulationKey;
    _ = ciphertext;
    _ = sharedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: decapsulateBits
pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: anyopaque, decapsulationKey: anyopaque, ciphertext: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = decapsulationAlgorithm;
    _ = decapsulationKey;
    _ = ciphertext;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPublicKey
pub fn call_getPublicKey(instance: *runtime.Instance, key: anyopaque, keyUsages: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = key;
    _ = keyUsages;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, operation: runtime.DOMString, algorithm: anyopaque, length: anyopaque) ImplError!bool {
    _ = instance;
    _ = operation;
    _ = algorithm;
    _ = length;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: supports
pub fn call_supports(instance: *runtime.Instance, operation: runtime.DOMString, algorithm: anyopaque, additionalAlgorithm: anyopaque) ImplError!bool {
    _ = instance;
    _ = operation;
    _ = algorithm;
    _ = additionalAlgorithm;
    // TODO: Implement operation
    return error.NotImplemented;
}


//! Generated from: webcrypto.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SubtleCryptoImpl = @import("../impls/SubtleCrypto.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        SubtleCryptoImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SubtleCryptoImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_generateKey(instance: *runtime.Instance, algorithm: anyopaque, extractable: bool, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_generateKey(state, algorithm, extractable, keyUsages);
    }

    pub fn call_exportKey(instance: *runtime.Instance, format: anyopaque, key: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_exportKey(state, format, key);
    }

    pub fn call_sign(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_sign(state, algorithm, key, data);
    }

    pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: anyopaque, encapsulationKey: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_encapsulateBits(state, encapsulationAlgorithm, encapsulationKey);
    }

    pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: anyopaque, decapsulationKey: anyopaque, ciphertext: anyopaque, sharedKeyAlgorithm: anyopaque, extractable: bool, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_decapsulateKey(state, decapsulationAlgorithm, decapsulationKey, ciphertext, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_deriveBits(instance: *runtime.Instance, algorithm: anyopaque, baseKey: anyopaque, length: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_deriveBits(state, algorithm, baseKey, length);
    }

    pub fn call_getPublicKey(instance: *runtime.Instance, key: anyopaque, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_getPublicKey(state, key, keyUsages);
    }

    pub fn call_deriveKey(instance: *runtime.Instance, algorithm: anyopaque, baseKey: anyopaque, derivedKeyType: anyopaque, extractable: bool, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_deriveKey(state, algorithm, baseKey, derivedKeyType, extractable, keyUsages);
    }

    pub fn call_verify(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, signature: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_verify(state, algorithm, key, signature, data);
    }

    /// Arguments for supports (WebIDL overloading)
    pub const SupportsArgs = union(enum) {
        /// supports(operation, algorithm, length)
        string_AlgorithmIdentifier_long?: struct {
            operation: runtime.DOMString,
            algorithm: anyopaque,
            length: anyopaque,
        },
        /// supports(operation, algorithm, additionalAlgorithm)
        string_AlgorithmIdentifier_AlgorithmIdentifier: struct {
            operation: runtime.DOMString,
            algorithm: anyopaque,
            additionalAlgorithm: anyopaque,
        },
    };

    pub fn call_supports(instance: *runtime.Instance, args: SupportsArgs) bool {
        const state = instance.getState(State);
        switch (args) {
            .string_AlgorithmIdentifier_long? => |a| return SubtleCryptoImpl.string_AlgorithmIdentifier_long?(state, a.operation, a.algorithm, a.length),
            .string_AlgorithmIdentifier_AlgorithmIdentifier => |a| return SubtleCryptoImpl.string_AlgorithmIdentifier_AlgorithmIdentifier(state, a.operation, a.algorithm, a.additionalAlgorithm),
        }
    }

    pub fn call_digest(instance: *runtime.Instance, algorithm: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_digest(state, algorithm, data);
    }

    pub fn call_importKey(instance: *runtime.Instance, format: anyopaque, keyData: anyopaque, algorithm: anyopaque, extractable: bool, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_importKey(state, format, keyData, algorithm, extractable, keyUsages);
    }

    pub fn call_wrapKey(instance: *runtime.Instance, format: anyopaque, key: anyopaque, wrappingKey: anyopaque, wrapAlgorithm: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_wrapKey(state, format, key, wrappingKey, wrapAlgorithm);
    }

    pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: anyopaque, decapsulationKey: anyopaque, ciphertext: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_decapsulateBits(state, decapsulationAlgorithm, decapsulationKey, ciphertext);
    }

    pub fn call_unwrapKey(instance: *runtime.Instance, format: anyopaque, wrappedKey: anyopaque, unwrappingKey: anyopaque, unwrapAlgorithm: anyopaque, unwrappedKeyAlgorithm: anyopaque, extractable: bool, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_unwrapKey(state, format, wrappedKey, unwrappingKey, unwrapAlgorithm, unwrappedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: anyopaque, encapsulationKey: anyopaque, sharedKeyAlgorithm: anyopaque, extractable: bool, keyUsages: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_encapsulateKey(state, encapsulationAlgorithm, encapsulationKey, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_decrypt(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_decrypt(state, algorithm, key, data);
    }

    pub fn call_encrypt(instance: *runtime.Instance, algorithm: anyopaque, key: anyopaque, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SubtleCryptoImpl.call_encrypt(state, algorithm, key, data);
    }

};

//! Generated from: webcrypto.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SubtleCryptoImpl = @import("impls").SubtleCrypto;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EncapsulatedBits = @import("dictionaries").EncapsulatedBits;
const AlgorithmIdentifier = @import("typedefs").AlgorithmIdentifier;
const KeyUsage = @import("enums").KeyUsage;
const KeyFormat = @import("enums").KeyFormat;
const BufferSource = @import("typedefs").BufferSource;
const BufferSourceOrJsonWebKey = @import("typedefs").BufferSourceOrJsonWebKey;
const EncapsulatedKey = @import("dictionaries").EncapsulatedKey;
const DOMString = @import("typedefs").DOMString;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SubtleCrypto = struct {
    pub const Meta = struct {
        pub const name = "SubtleCrypto";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "supports", "call_static_supports", 2 },
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
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "encapsulateKey",
            "encapsulateBits",
            "decapsulateKey",
            "decapsulateBits",
            "getPublicKey",
        };

        /// [SecureContext] static members: hidden from the interface object
        /// of a realm that is not a secure context (WebIDL 3.3.13).
        pub const secure_context_static_members = .{
            "supports",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SubtleCryptoImpl.InternalState = null,
        },
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
        .call_unwrapKey = &call_unwrapKey,
        .call_verify = &call_verify,
        .call_wrapKey = &call_wrapKey,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("SubtleCrypto has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(SubtleCryptoImpl, "init") and @hasDecl(SubtleCryptoImpl, "initOwn")) @compileError("SubtleCryptoImpl defines both init and initOwn");
        if (comptime @hasDecl(SubtleCryptoImpl, "init")) return SubtleCryptoImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SubtleCryptoImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SubtleCryptoImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SubtleCryptoImpl, "init")) return false;
        if (comptime @hasDecl(SubtleCryptoImpl, "construction_args")) {
            inline for (SubtleCryptoImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(SubtleCryptoImpl, "deinit") and @hasDecl(SubtleCryptoImpl, "deinitOwn")) @compileError("SubtleCryptoImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SubtleCryptoImpl, "deinit")) return SubtleCryptoImpl.deinit(instance);
        if (comptime @hasDecl(SubtleCryptoImpl, "deinitOwn")) SubtleCryptoImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SubtleCrypto")) {
            if (comptime @hasDecl(impls.SubtleCrypto, "installHooks")) impls.SubtleCrypto.installHooks();
        }
    }

    pub fn call_deriveBits(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, baseKey: *runtime.Instance, length: webidl.Opt(?u32)) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_deriveBits(instance, algorithm, baseKey, length);
    }

    pub fn call_encrypt(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: *runtime.Instance, data: BufferSource) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_encrypt(instance, algorithm, key, data);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: AlgorithmIdentifier, decapsulationKey: *runtime.Instance, ciphertext: BufferSource, sharedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_decapsulateKey(instance, decapsulationAlgorithm, decapsulationKey, ciphertext, sharedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_wrapKey(instance: *runtime.Instance, format: KeyFormat, key: *runtime.Instance, wrappingKey: *runtime.Instance, wrapAlgorithm: AlgorithmIdentifier) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_wrapKey(instance, format, key, wrappingKey, wrapAlgorithm);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: AlgorithmIdentifier, decapsulationKey: *runtime.Instance, ciphertext: BufferSource) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_decapsulateBits(instance, decapsulationAlgorithm, decapsulationKey, ciphertext);
    }

    pub fn call_digest(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, data: BufferSource) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_digest(instance, algorithm, data);
    }

    pub fn call_sign(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: *runtime.Instance, data: BufferSource) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_sign(instance, algorithm, key, data);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_static_supports(instance: *runtime.Instance, operation: DOMString, algorithm: AlgorithmIdentifier, length: webidl.Opt(?u32)) anyerror!bool {
        return try SubtleCryptoImpl.call_static_supports(instance, operation, algorithm, length);
    }

    pub fn call_deriveKey(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, baseKey: *runtime.Instance, derivedKeyType: AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_deriveKey(instance, algorithm, baseKey, derivedKeyType, extractable, keyUsages);
    }

    pub fn call_verify(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: *runtime.Instance, signature: BufferSource, data: BufferSource) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_verify(instance, algorithm, key, signature, data);
    }

    pub fn call_importKey(instance: *runtime.Instance, format: KeyFormat, keyData: BufferSourceOrJsonWebKey, algorithm: AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_importKey(instance, format, keyData, algorithm, extractable, keyUsages);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: AlgorithmIdentifier, encapsulationKey: *runtime.Instance, sharedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_encapsulateKey(instance, encapsulationAlgorithm, encapsulationKey, sharedKeyAlgorithm, extractable, keyUsages);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_getPublicKey(instance: *runtime.Instance, key: *runtime.Instance, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_getPublicKey(instance, key, keyUsages);
    }

    pub fn call_decrypt(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, key: *runtime.Instance, data: BufferSource) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_decrypt(instance, algorithm, key, data);
    }

    pub fn call_generateKey(instance: *runtime.Instance, algorithm: AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_generateKey(instance, algorithm, extractable, keyUsages);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: AlgorithmIdentifier, encapsulationKey: *runtime.Instance) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_encapsulateBits(instance, encapsulationAlgorithm, encapsulationKey);
    }

    pub fn call_unwrapKey(instance: *runtime.Instance, format: KeyFormat, wrappedKey: BufferSource, unwrappingKey: *runtime.Instance, unwrapAlgorithm: AlgorithmIdentifier, unwrappedKeyAlgorithm: AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_unwrapKey(instance, format, wrappedKey, unwrappingKey, unwrapAlgorithm, unwrappedKeyAlgorithm, extractable, keyUsages);
    }

    pub fn call_exportKey(instance: *runtime.Instance, format: KeyFormat, key: *runtime.Instance) anyerror!runtime.JSValue {
        return try SubtleCryptoImpl.call_exportKey(instance, format, key);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_deriveBits",
        "call_encrypt",
        "call_decapsulateKey",
        "call_wrapKey",
        "call_decapsulateBits",
        "call_digest",
        "call_sign",
        "call_deriveKey",
        "call_verify",
        "call_importKey",
        "call_encapsulateKey",
        "call_getPublicKey",
        "call_decrypt",
        "call_generateKey",
        "call_encapsulateBits",
        "call_unwrapKey",
        "call_exportKey",
    };
};

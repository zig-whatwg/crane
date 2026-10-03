//! Implementation for SubtleCrypto interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const webcrypto = @import("webcrypto");
const engine = @import("engine");
const dom = @import("dom");
const Request = webcrypto.operations.Request;
const SubtleCrypto = interfaces.SubtleCrypto;

pub const State = SubtleCrypto.State;

pub const ImplError = error{
    NotSupportedError,
};

/// SubtleCrypto itself is stateless; each operation owns its copied inputs.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: generateKey
pub fn call_generateKey(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    var request = newRequest(.generate_key);
    defer request.deinit(instance.ctx.allocator);
    // WebIDL sequence<KeyUsage> conversion precedes §14.3.6 steps 1-3.
    request.usages = try webcrypto.inputs.usages(instance.ctx, keyUsages);
    request.algorithm = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(algorithm), .generate_key);
    request.extractable = extractable;
    // Steps 4-12: copied native work and a later settlement task.
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: exportKey
pub fn call_exportKey(instance: *runtime.Instance, format: enums.KeyFormat, key: *runtime.Instance) anyerror!runtime.JSValue {
    var request = newRequest(.export_key);
    defer request.deinit(instance.ctx.allocator);
    // §14.3.10 steps 1-4; support/extractability checks run in the task, in order.
    request.format = keyFormat(format);
    request.key = try copyKey(instance.ctx.allocator, key);
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: sign
pub fn call_sign(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: *runtime.Instance, data: typedefs.BufferSource) anyerror!runtime.JSValue {
    return dataOperation(instance, algorithm, key, data, .sign);
}

/// Operation: encapsulateBits
pub fn call_encapsulateBits(instance: *runtime.Instance, encapsulationAlgorithm: typedefs.AlgorithmIdentifier, encapsulationKey: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    _ = encapsulationAlgorithm;
    _ = encapsulationKey;
    return error.NotSupportedError;
}

/// Operation: decapsulateKey
pub fn call_decapsulateKey(instance: *runtime.Instance, decapsulationAlgorithm: typedefs.AlgorithmIdentifier, decapsulationKey: *runtime.Instance, ciphertext: typedefs.BufferSource, sharedKeyAlgorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    _ = instance;
    _ = decapsulationAlgorithm;
    _ = decapsulationKey;
    _ = ciphertext;
    _ = sharedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotSupportedError;
}

/// Operation: deriveBits
pub fn call_deriveBits(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, baseKey: *runtime.Instance, length: webidl.Opt(?u32)) anyerror!runtime.JSValue {
    var request = newRequest(.derive_bits);
    defer request.deinit(instance.ctx.allocator);
    // §14.3.8 steps 1-3: omitted length has the IDL default null.
    request.algorithm = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(algorithm), .derive_bits);
    request.length = if (length.was_passed) length.value else null;
    request.key = try copyKey(instance.ctx.allocator, baseKey);
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: getPublicKey
pub fn call_getPublicKey(instance: *runtime.Instance, key: *runtime.Instance, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    _ = instance;
    _ = key;
    _ = keyUsages;
    return error.NotSupportedError;
}

/// Operation: deriveKey
pub fn call_deriveKey(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, baseKey: *runtime.Instance, derivedKeyType: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    var request = newRequest(.derive_key);
    defer request.deinit(instance.ctx.allocator);
    request.usages = try webcrypto.inputs.usages(instance.ctx, keyUsages);
    // §14.3.7 steps 2-7: normalize all THREE operations, in this order.
    request.algorithm = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(algorithm), .derive_bits);
    request.derived_import = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(derivedKeyType), .import_key);
    request.derived_length = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(derivedKeyType), .get_key_length);
    request.extractable = extractable;
    request.key = try copyKey(instance.ctx.allocator, baseKey);
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: verify
pub fn call_verify(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: *runtime.Instance, signature: typedefs.BufferSource, data: typedefs.BufferSource) anyerror!runtime.JSValue {
    var request = newRequest(.verify);
    defer request.deinit(instance.ctx.allocator);
    // §14.3.4 steps 2-5: normalization, signature copy, then message copy.
    request.algorithm = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(algorithm), .verify);
    request.signature = try copyTypedBufferSource(instance.ctx, signature);
    request.bytes = try copyTypedBufferSource(instance.ctx, data);
    request.key = try copyKey(instance.ctx.allocator, key);
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: supports
pub fn call_static_supports(instance: *runtime.Instance, operation: runtime.DOMString, algorithm: typedefs.AlgorithmIdentifier, length: webidl.Opt(?u32)) anyerror!bool {
    _ = instance;
    _ = operation;
    _ = algorithm;
    _ = length;
    return false;
}

/// Operation: digest
pub fn call_digest(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, data: typedefs.BufferSource) anyerror!runtime.JSValue {
    // §14.3.5 steps 1-3. The Promise-returning binding preserves abrupt
    // completion, including an exception a name getter left pending.
    var normalized = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(algorithm), .digest);
    defer normalized.deinit();
    // Step 4: read the live BufferSource AFTER normalization's getters run.
    const bytes = try copyTypedBufferSource(instance.ctx, data);
    // Steps 5-12: digest in the relevant realm and settle from its crypto task.
    return webcrypto.tasks.submit(instance.ctx, DigestInput{ .id = normalized.id, .bytes = bytes });
}

fn algorithmInput(algorithm: typedefs.AlgorithmIdentifier) webcrypto.normalize.Input {
    return switch (algorithm) {
        .object => |value| .{ .object = value },
        .domstring => |value| .{ .string = value.asSlice() },
    };
}

const DigestInput = struct {
    id: webcrypto.registry.Id,
    bytes: []u8,

    pub fn run(self: *const DigestInput, allocator: std.mem.Allocator) !webcrypto.tasks.Result {
        const hash = try webcrypto.hash.Hash.fromName(self.id.name());
        return .{ .bytes = try webcrypto.hash.digest(allocator, hash, self.bytes) };
    }

    pub fn deinit(self: *DigestInput, allocator: std.mem.Allocator) void {
        std.crypto.secureZero(u8, self.bytes);
        allocator.free(self.bytes);
    }
};

/// Operation: importKey
pub fn call_importKey(instance: *runtime.Instance, format: enums.KeyFormat, keyData: typedefs.BufferSourceOrJsonWebKey, algorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    const realm = instance.ctx;
    // keyData, (BufferSource or JsonWebKey), was converted by the binding in
    // argument order - its dictionary's getters before `algorithm`'s
    // conversion (WebIDL 3.7.6): a BufferSource as a reference to its object,
    // a JsonWebKey as the binding's dictionary, whose strings it frees when
    // this returns. keyUsages, the last argument, is converted here, before
    // the method's steps.
    const Jwk = struct {
        const Data = webcrypto.jwk.Data;

        fn text(allocator: std.mem.Allocator, value: ?runtime.DOMString) !?[]const u8 {
            const string = value orelse return null;
            return try allocator.dupe(u8, string.asSlice());
        }

        /// The binding's dictionary as the operation's own, independent of
        /// the binding's storage.
        fn copy(allocator: std.mem.Allocator, dictionary: dictionaries.JsonWebKey) !webcrypto.jwk.Owned {
            var owned: webcrypto.jwk.Owned = .{};
            errdefer owned.deinit(allocator);
            inline for (std.meta.fields(Data)) |field| {
                const member = @field(dictionary, field.name);
                if (field.type == ?[]const u8) {
                    @field(owned.data, field.name) = try text(allocator, member);
                } else if (comptime std.mem.eql(u8, field.name, "ext")) {
                    owned.data.ext = member;
                } else if (comptime std.mem.eql(u8, field.name, "key_ops")) {
                    if (member) |operations| {
                        const list = try allocator.alloc([]const u8, operations.len);
                        var filled: usize = 0;
                        errdefer {
                            for (list[0..filled]) |operation| allocator.free(operation);
                            allocator.free(list);
                        }
                        for (operations, list) |operation, *slot| {
                            slot.* = try allocator.dupe(u8, operation.asSlice());
                            filled += 1;
                        }
                        owned.data.key_ops = list;
                    }
                } else if (comptime std.mem.eql(u8, field.name, "oth")) {
                    if (member) |primes| {
                        const list = try allocator.alloc(webcrypto.jwk.OtherPrime, primes.len);
                        for (list) |*slot| slot.* = .{};
                        owned.data.oth = list;
                        for (primes, list) |prime, *slot| {
                            slot.r = try text(allocator, prime.r);
                            slot.d = try text(allocator, prime.d);
                            slot.t = try text(allocator, prime.t);
                        }
                    }
                }
            }
            return owned;
        }

        /// Key material does not outlive the call in the binding's freed
        /// strings either: zero them before the binding frees them.
        fn erase(dictionary: dictionaries.JsonWebKey) void {
            inline for (std.meta.fields(dictionaries.JsonWebKey)) |field| {
                const member = @field(dictionary, field.name);
                if (field.type == ?runtime.DOMString) {
                    if (member) |string| zero(string);
                } else if (comptime std.mem.eql(u8, field.name, "key_ops")) {
                    if (member) |operations| for (operations) |operation| zero(operation);
                } else if (comptime std.mem.eql(u8, field.name, "oth")) {
                    if (member) |primes| for (primes) |prime| {
                        if (prime.r) |string| zero(string);
                        if (prime.d) |string| zero(string);
                        if (prime.t) |string| zero(string);
                    };
                }
            }
        }

        fn zero(string: runtime.DOMString) void {
            switch (string) {
                .owned => |bytes| std.crypto.secureZero(u8, @constCast(bytes)),
                .empty, .interned => {},
            }
        }
    };
    defer if (keyData == .json_web_key) Jwk.erase(keyData.json_web_key);
    var request = newRequest(.import_key);
    defer request.deinit(realm.allocator);
    request.usages = try webcrypto.inputs.usages(realm, keyUsages);
    // §14.3.9 steps 2-3: normalize before checking the format/union pairing.
    request.algorithm = try webcrypto.normalize.algorithm(realm, algorithmInput(algorithm), .import_key);
    request.format = keyFormat(format);
    request.extractable = extractable;
    // Step 4: dictionary or a copy of the BufferSource's CURRENT contents.
    if (request.format == .jwk) {
        if (keyData != .json_web_key) return error.TypeError;
        request.dictionary = try Jwk.copy(realm.allocator, keyData.json_web_key);
    } else {
        if (keyData != .buffer_source) return error.TypeError;
        request.bytes = try copyBufferValue(realm, keyData.buffer_source.jsValue(runtime.JSValue) orelse return error.TypeError);
    }
    return webcrypto.tasks.submit(realm, request.take());
}

/// Operation: wrapKey
pub fn call_wrapKey(instance: *runtime.Instance, format: enums.KeyFormat, key: *runtime.Instance, wrappingKey: *runtime.Instance, wrapAlgorithm: typedefs.AlgorithmIdentifier) anyerror!runtime.JSValue {
    var request = newRequest(.wrap_key);
    defer request.deinit(instance.ctx.allocator);
    // §14.3.11 steps 2-4: retry ANY abrupt normalization as encrypt.
    request.algorithm = try normalizeWrap(instance.ctx, algorithmInput(wrapAlgorithm), .wrap_key, .encrypt);
    request.format = keyFormat(format);
    request.key = try copyKey(instance.ctx.allocator, wrappingKey);
    request.other_key = try copyKey(instance.ctx.allocator, key);
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: decapsulateBits
pub fn call_decapsulateBits(instance: *runtime.Instance, decapsulationAlgorithm: typedefs.AlgorithmIdentifier, decapsulationKey: *runtime.Instance, ciphertext: typedefs.BufferSource) anyerror!runtime.JSValue {
    _ = instance;
    _ = decapsulationAlgorithm;
    _ = decapsulationKey;
    _ = ciphertext;
    return error.NotSupportedError;
}

/// Operation: unwrapKey
pub fn call_unwrapKey(instance: *runtime.Instance, format: enums.KeyFormat, wrappedKey: typedefs.BufferSource, unwrappingKey: *runtime.Instance, unwrapAlgorithm: typedefs.AlgorithmIdentifier, unwrappedKeyAlgorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    var request = newRequest(.unwrap_key);
    defer request.deinit(instance.ctx.allocator);
    request.usages = try webcrypto.inputs.usages(instance.ctx, keyUsages);
    // §14.3.12 steps 2-7: unwrap/decrypt, import, then copy the wrapped bytes.
    request.algorithm = try normalizeWrap(instance.ctx, algorithmInput(unwrapAlgorithm), .unwrap_key, .decrypt);
    request.derived_import = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(unwrappedKeyAlgorithm), .import_key);
    request.bytes = try copyTypedBufferSource(instance.ctx, wrappedKey);
    request.key = try copyKey(instance.ctx.allocator, unwrappingKey);
    request.format = keyFormat(format);
    request.extractable = extractable;
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

/// Operation: encapsulateKey
pub fn call_encapsulateKey(instance: *runtime.Instance, encapsulationAlgorithm: typedefs.AlgorithmIdentifier, encapsulationKey: *runtime.Instance, sharedKeyAlgorithm: typedefs.AlgorithmIdentifier, extractable: bool, keyUsages: runtime.JSValue) anyerror!runtime.JSValue {
    _ = instance;
    _ = encapsulationAlgorithm;
    _ = encapsulationKey;
    _ = sharedKeyAlgorithm;
    _ = extractable;
    _ = keyUsages;
    return error.NotSupportedError;
}

/// Operation: decrypt
pub fn call_decrypt(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: *runtime.Instance, data: typedefs.BufferSource) anyerror!runtime.JSValue {
    return dataOperation(instance, algorithm, key, data, .decrypt);
}

/// Operation: encrypt
pub fn call_encrypt(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: *runtime.Instance, data: typedefs.BufferSource) anyerror!runtime.JSValue {
    return dataOperation(instance, algorithm, key, data, .encrypt);
}

fn newRequest(operation: webcrypto.operations.Operation) Request {
    return .{ .operation = operation, .io = @import("host").io() };
}

fn dataOperation(instance: *runtime.Instance, algorithm: typedefs.AlgorithmIdentifier, key: *runtime.Instance, data: typedefs.BufferSource, comptime operation: webcrypto.operations.Operation) !runtime.JSValue {
    var request = newRequest(operation);
    defer request.deinit(instance.ctx.allocator);
    // §§14.3.1-3 steps 2-4: normalization precedes copying the data argument.
    const operation_id: webcrypto.registry.Operation = switch (operation) {
        .encrypt => .encrypt,
        .decrypt => .decrypt,
        .sign => .sign,
        else => unreachable,
    };
    request.algorithm = try webcrypto.normalize.algorithm(instance.ctx, algorithmInput(algorithm), operation_id);
    request.bytes = try copyTypedBufferSource(instance.ctx, data);
    request.key = try copyKey(instance.ctx.allocator, key);
    return webcrypto.tasks.submit(instance.ctx, request.take());
}

fn copyKey(allocator: std.mem.Allocator, instance: *runtime.Instance) !webcrypto.key.Slots {
    const key = dom.crypto_keys.get(instance) orelse return error.TypeError;
    return webcrypto.key.Slots.init(allocator, key.kind, key.extractable, key.algorithm, key.usages, key.material);
}

fn copyBufferValue(realm: runtime.Context, value: runtime.JSValue) ![]u8 {
    return (try engine.getCopyOfBufferSourceBytes(realm, value, realm.allocator)) orelse error.TypeError;
}

fn copyTypedBufferSource(realm: runtime.Context, source: typedefs.BufferSource) ![]u8 {
    // Q18 supersedes Q7's early byte copy. The adapter lane supplies a borrowed
    // JS-value accessor; wire that value into copyBufferValue here when it
    // lands. An asBytes copy would freeze data BEFORE algorithm getters run.
    // TODO(Q18): use the adapter's exact accessor, without retyping the IDL.
    _ = realm;
    _ = source;
    return error.NotSupportedError;
}

fn keyFormat(format: enums.KeyFormat) webcrypto.operations.Format {
    return switch (format) {
        ._raw_ => .raw,
        ._spki_ => .spki,
        ._pkcs8_ => .pkcs8,
        ._jwk_ => .jwk,
        else => .unsupported,
    };
}

fn normalizeWrap(realm: runtime.Context, input: webcrypto.normalize.Input, first: webcrypto.registry.Operation, fallback: webcrypto.registry.Operation) !webcrypto.normalize.Algorithm {
    const Attempt = struct {
        realm: runtime.Context,
        input: webcrypto.normalize.Input,
        operation: webcrypto.registry.Operation,
        result: ?webcrypto.normalize.Algorithm = null,

        fn steps(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = webcrypto.normalize.algorithm(self.realm, self.input, self.operation) catch |err| switch (err) {
                error.ExceptionPending => return error.ExceptionPending,
                error.TypeError => return error.TypeError,
                else => return,
            };
        }
    };
    var attempt: Attempt = .{ .realm = realm, .input = input, .operation = first };
    // §§14.3.11/12 step 3 consumes the FIRST abrupt completion. Clear and
    // release its thrown value before invoking any getter a second time.
    const thrown = try engine.completionOf(realm, Attempt.steps, &attempt);
    if (thrown) |reason| reason.release();
    if (attempt.result) |result| return result;
    return webcrypto.normalize.algorithm(realm, input, fallback);
}

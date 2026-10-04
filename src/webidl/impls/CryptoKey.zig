//! Implementation for CryptoKey interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const engine = @import("engine");
const keys = @import("webcrypto").key;
const crypto_keys = @import("dom").crypto_keys;
const CryptoKey = interfaces.CryptoKey;

pub const State = CryptoKey.State;

pub const ImplError = error{
    NotImplemented,
};

/// Native slots own their bytes. No persistent engine handles or PSA key IDs.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    slots: ?keys.Slots = null,
};

pub fn installHooks() void {
    crypto_keys.install(.{ .create = &createKey, .get = &keySlots });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.slots) |*slots| slots.deinit();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn createKey(realm: runtime.Context, slots: keys.Slots) !*runtime.Instance {
    const instance = try interfaces.CryptoKey.init(realm.allocator, realm);
    instance.getState(State).own._internal.?.slots = slots;
    return instance;
}

fn keySlots(instance: *runtime.Instance) ?*const keys.Slots {
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    if (internal.slots) |*slots| return slots;
    return null;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!enums.KeyType {
    // §13.4: reflect [[type]], not a script property.
    const slots = keySlots(instance) orelse return error.InvalidStateError;
    return switch (slots.kind) {
        .public => ._public_,
        .private => ._private_,
        .secret => ._secret_,
    };
}

/// Getter for extractable
pub fn get_extractable(instance: *runtime.Instance) anyerror!bool {
    // §13.4: reflect [[extractable]].
    return (keySlots(instance) orelse return error.InvalidStateError).extractable;
}

/// Getter for algorithm
pub fn get_algorithm(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // §9 cached-object conversion, §13.4: construct in the key's realm.
    // TODO(Q8): cache through the adapter's forthcoming traced-value operation.
    // A retained Owned here would keep realm/owner cycles alive.
    const algorithm = (keySlots(instance) orelse return error.InvalidStateError).algorithm;
    var members: [6]engine.DictionaryMember = undefined;
    var count: usize = 1;
    members[0] = .{ .name = "name", .value = runtime.JSValue.fromStringRef(algorithm.id.name()) };
    var hash: ?engine.Owned = null;
    defer if (hash) |value| value.release();
    var exponent_buffer: ?engine.Owned = null;
    defer if (exponent_buffer) |value| value.release();
    var exponent_view: ?engine.Owned = null;
    defer if (exponent_view) |value| value.release();
    // WebIDL §3.2.17 step 3: inherited dictionaries before derived ones,
    // with each dictionary's own members in lexicographic order. RSA's
    // modulusLength/publicExponent precede RsaHashedKeyAlgorithm.hash;
    // HmacKeyAlgorithm itself declares hash before length.
    if (algorithm.modulus_length) |value| {
        members[count] = .{ .name = "modulusLength", .value = .{ .number = @floatFromInt(value) } };
        count += 1;
    }
    if (algorithm.public_exponent) |value| {
        exponent_buffer = try engine.createArrayBuffer(instance.ctx, value);
        exponent_view = try engine.createArrayBufferView(instance.ctx, .uint8_array, exponent_buffer.?.borrow(), 0, value.len);
        members[count] = .{ .name = "publicExponent", .value = exponent_view.?.borrow() };
        count += 1;
    }
    if (algorithm.hash) |value| {
        hash = try engine.createDictionaryObject(instance.ctx, &.{.{ .name = "name", .value = runtime.JSValue.fromStringRef(value.name()) }});
        members[count] = .{ .name = "hash", .value = hash.?.borrow() };
        count += 1;
    }
    if (algorithm.length) |value| {
        members[count] = .{ .name = "length", .value = .{ .number = @floatFromInt(value) } };
        count += 1;
    }
    if (algorithm.named_curve) |value| {
        members[count] = .{ .name = "namedCurve", .value = runtime.JSValue.fromStringRef(value.name()) };
        count += 1;
    }
    return (try engine.createDictionaryObject(instance.ctx, members[0..count])).take();
}

/// Getter for usages
pub fn get_usages(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // §9 and §13.4: reflect normalized usages, with the same Q8 cache gap.
    const slots = keySlots(instance) orelse return error.InvalidStateError;
    var values: [std.meta.tags(keys.Usage).len]runtime.JSValue = undefined;
    var count: usize = 0;
    var usages = slots.usages.iterator();
    while (usages.next()) |usage| {
        values[count] = runtime.JSValue.fromStringRef(@tagName(usage));
        count += 1;
    }
    return (try engine.createSequenceOfValues(instance.ctx, values[0..count])).take();
}

// ============================================================================
// Serializable objects (HTML 2.7.1; WebCrypto 13.5: CryptoKey is
// [Serializable])
// ============================================================================

/// WebCrypto 13.5, CryptoKey's serialization steps, given `value` and
/// `serialized`:
///
/// 1. Set serialized.[[Type]] to value.[[type]].
/// 2. Set serialized.[[Extractable]] to value.[[extractable]].
/// 3. Set serialized.[[Algorithm]] to the sub-serialization of
///    value.[[algorithm]].
/// 4. Set serialized.[[Usages]] to the sub-serialization of value.[[usages]].
/// 5. Set serialized.[[Handle]] to value.[[handle]].
///
/// Deviation (steps 3-4): this key keeps no [[algorithm]] or [[usages]]
/// object to sub-serialize - its getters make them from its native slots
/// each time (the cache is Codex's WebCrypto Q8) - so the record carries
/// those slots, from which the copy's getters make the same objects. Step 5
/// is the key material, copied: the handle of this agent's key cannot cross
/// to another (a worker, an IndexedDB record). Every enum is written by
/// name, so a stored key reads back after the enums are reordered.
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    const slots = keySlots(value) orelse return error.DataCloneError;
    // Steps 1-2.
    try serialized.writeString(@tagName(slots.kind));
    try serialized.writeBool(slots.extractable);
    // Step 3: [[algorithm]], as its slots.
    const algorithm = slots.algorithm;
    try serialized.writeString(@tagName(algorithm.id));
    try writeOptionalName(serialized, if (algorithm.hash) |hash| @tagName(hash) else null);
    try writeOptionalUint32(serialized, algorithm.length);
    try writeOptionalUint32(serialized, algorithm.modulus_length);
    try serialized.writeBool(algorithm.public_exponent != null);
    try serialized.writeBytes(algorithm.public_exponent orelse "");
    try writeOptionalName(serialized, if (algorithm.named_curve) |curve| @tagName(curve) else null);
    // Step 4: [[usages]], in recognized-usage order.
    try serialized.writeUint32(@intCast(slots.usages.count()));
    var usages = slots.usages.iterator();
    while (usages.next()) |usage| try serialized.writeString(@tagName(usage));
    // Step 5.
    try serialized.writeBytes(slots.material);
}

/// WebCrypto 13.5, CryptoKey's deserialization steps, given `serialized` and
/// `value`: initialize [[type]], [[extractable]], [[algorithm]], [[usages]]
/// and [[handle]] from serialized's (see the serialization steps for the
/// form [[algorithm]] and [[usages]] take). A record naming anything this
/// build does not know is a DataCloneError: the key is never made as
/// something else.
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    _ = target_realm;
    // Steps 1-2.
    const kind = try readName(serialized, keys.Kind);
    const extractable = try serialized.readBool();
    // Step 3.
    var algorithm: keys.Algorithm = .{ .id = try readName(serialized, @import("webcrypto").registry.Id) };
    if (try readOptionalString(serialized)) |hash| algorithm.hash = std.meta.stringToEnum(@import("webcrypto").hash.Hash, hash) orelse return error.DataCloneError;
    algorithm.length = try readOptionalUint32(serialized);
    algorithm.modulus_length = try readOptionalUint32(serialized);
    const has_exponent = try serialized.readBool();
    const exponent = try serialized.readBytes();
    if (has_exponent) algorithm.public_exponent = exponent;
    if (try readOptionalString(serialized)) |curve| algorithm.named_curve = std.meta.stringToEnum(keys.Curve, curve) orelse return error.DataCloneError;
    // Step 4.
    var usages = keys.Usages.initEmpty();
    const usage_count = try serialized.readUint32();
    for (0..usage_count) |_| usages.insert(try readName(serialized, keys.Usage));
    // Step 5: the material, copied into slots this key owns (Slots.init
    // copies it and the exponent).
    const material = try serialized.readBytes();
    const internal = value.getState(State).own._internal orelse return error.DataCloneError;
    internal.slots = try keys.Slots.init(internal.allocator, kind, extractable, algorithm, usages, material);
}

fn writeOptionalName(serialized: *runtime.SerializationRecord, name: ?[]const u8) !void {
    try serialized.writeBool(name != null);
    try serialized.writeString(name orelse "");
}

fn readOptionalString(serialized: *runtime.DeserializationRecord) !?[]const u8 {
    const present = try serialized.readBool();
    const text = try serialized.readString();
    return if (present) text else null;
}

fn writeOptionalUint32(serialized: *runtime.SerializationRecord, number: ?u32) !void {
    try serialized.writeBool(number != null);
    try serialized.writeUint32(number orelse 0);
}

fn readOptionalUint32(serialized: *runtime.DeserializationRecord) !?u32 {
    const present = try serialized.readBool();
    const number = try serialized.readUint32();
    return if (present) number else null;
}

/// An enum written by its tag name; an unknown name is a DataCloneError.
fn readName(serialized: *runtime.DeserializationRecord, comptime E: type) !E {
    return std.meta.stringToEnum(E, try serialized.readString()) orelse error.DataCloneError;
}

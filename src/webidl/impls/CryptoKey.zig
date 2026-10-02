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
    if (algorithm.hash) |value| {
        hash = try engine.createDictionaryObject(instance.ctx, &.{.{ .name = "name", .value = runtime.JSValue.fromStringRef(value.name()) }});
        members[count] = .{ .name = "hash", .value = hash.?.borrow() };
        count += 1;
    }
    if (algorithm.length) |value| {
        members[count] = .{ .name = "length", .value = .{ .number = @floatFromInt(value) } };
        count += 1;
    }
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

//! WebCrypto §18.4.4: normalize an algorithm, including WebIDL dictionaries.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const registry = @import("registry.zig");
const key = @import("key.zig");
const Hash = @import("hash.zig").Hash;
const integers = @import("integers.zig");

pub const Input = union(enum) { string: []const u8, object: runtime.JSValue };

/// Normalization owns every byte needed after the caller's arguments disappear.
pub const Algorithm = struct {
    allocator: std.mem.Allocator,
    id: registry.Id,
    hash: ?Hash = null,
    length: ?u32 = null,
    modulus_length: ?u32 = null,
    salt_length: ?u32 = null,
    iterations: ?u32 = null,
    tag_length: ?u8 = null,
    named_curve: ?[]u8 = null,
    public_exponent: ?[]u8 = null,
    public_key: ?key.Slots = null,
    counter: ?[]u8 = null,
    iv: ?[]u8 = null,
    additional_data: ?[]u8 = null,
    salt: ?[]u8 = null,
    info: ?[]u8 = null,
    label: ?[]u8 = null,

    pub fn deinit(self: *Algorithm) void {
        inline for (.{ "named_curve", "public_exponent", "counter", "iv", "additional_data", "salt", "info", "label" }) |field| {
            if (@field(self, field)) |bytes| self.allocator.free(bytes);
        }
        if (self.public_key) |*slots| slots.deinit();
        self.* = undefined;
    }
};

pub fn algorithm(realm: runtime.Context, input: Input, operation: registry.Operation) anyerror!Algorithm {
    // String branch: a new Algorithm dictionary has only name. Converting it
    // has no observable getters; required algorithm-specific members are absent.
    if (input == .string) {
        const registration = try registry.lookup(input.string, operation);
        if (registration.dictionary != .algorithm and registration.dictionary != .rsa_oaep) return error.TypeError;
        return .{ .allocator = realm.allocator, .id = registration.id };
    }
    const object = input.object;
    // Object branch steps 1-5: convert Algorithm and look up its first name.
    const initial_name = try stringMember(realm, object, "name", true);
    defer realm.allocator.free(initial_name.?);
    const registration = try registry.lookup(initial_name.?, operation);
    var result: Algorithm = .{ .allocator = realm.allocator, .id = registration.id };
    errdefer result.deinit();

    // Step 6: a SECOND dictionary conversion reads name again, even for a
    // bare Algorithm. Step 7 ultimately uses the canonical first name.
    const converted_name = try stringMember(realm, object, "name", true);
    realm.allocator.free(converted_name.?);
    var converted: Converted = .{ .realm = realm };
    defer converted.deinit();

    // WebIDL dictionary conversion: inherited members before derived ones;
    // within each dictionary, lexicographic order. Do not recursively
    // normalize a hash or copy a retained BufferSource in this phase.
    switch (registration.dictionary) {
        .algorithm => {},
        .aes_length => result.length = (try integerMember(u16, realm, object, "length", true)).?,
        .aes_ctr => {
            converted.first = try bufferMember(realm, object, "counter", true, false);
            result.length = (try integerMember(u8, realm, object, "length", true)).?;
        },
        .aes_cbc => converted.first = try bufferMember(realm, object, "iv", true, false),
        .aes_gcm => {
            converted.second = try bufferMember(realm, object, "additionalData", false, false);
            converted.first = try bufferMember(realm, object, "iv", true, false);
            result.tag_length = try integerMember(u8, realm, object, "tagLength", false);
        },
        .hmac => {
            converted.hash = try hashMember(realm, object);
            result.length = try integerMember(u32, realm, object, "length", false);
        },
        .hkdf => {
            converted.hash = try hashMember(realm, object);
            converted.second = try bufferMember(realm, object, "info", true, false);
            converted.first = try bufferMember(realm, object, "salt", true, false);
        },
        .pbkdf2 => {
            converted.hash = try hashMember(realm, object);
            result.iterations = try integerMember(u32, realm, object, "iterations", true);
            converted.first = try bufferMember(realm, object, "salt", true, false);
        },
        .rsa_hashed_key_gen => {
            result.modulus_length = try integerMember(u32, realm, object, "modulusLength", true);
            converted.first = try bufferMember(realm, object, "publicExponent", true, true);
            converted.hash = try hashMember(realm, object);
        },
        .rsa_hashed_import, .ecdsa => converted.hash = try hashMember(realm, object),
        .rsa_pss => result.salt_length = try integerMember(u32, realm, object, "saltLength", true),
        .rsa_oaep => converted.first = try bufferMember(realm, object, "label", false, false),
        .ec_key => result.named_curve = try stringMember(realm, object, "namedCurve", true),
        .ecdh => {
            const value = try member(realm, object, "public", true);
            defer value.?.release();
            const instance = engine.convertToPlatformObject(realm, value.?.borrow()) orelse return error.TypeError;
            const slots = @import("dom").crypto_keys.get(instance) orelse return error.TypeError;
            result.public_key = try key.Slots.init(realm.allocator, slots.kind, slots.extractable, slots.algorithm, slots.usages, slots.material);
        },
    }

    // Steps 9-10: visit declaration order, after ALL dictionary conversions.
    // This matters when later getters mutate/detach buffers or throw before
    // a nested hash's name getter would run.
    switch (registration.dictionary) {
        .aes_ctr => result.counter = try converted.copy(converted.first),
        .aes_cbc => result.iv = try converted.copy(converted.first),
        .aes_gcm => {
            result.iv = try converted.copy(converted.first);
            result.additional_data = try converted.copy(converted.second);
        },
        .hkdf => {
            result.hash = try converted.normalizedHash();
            result.salt = try converted.copy(converted.first);
            result.info = try converted.copy(converted.second);
        },
        .pbkdf2 => {
            result.salt = try converted.copy(converted.first);
            result.hash = try converted.normalizedHash();
        },
        .rsa_hashed_key_gen => {
            result.public_exponent = try converted.copy(converted.first);
            result.hash = try converted.normalizedHash();
        },
        .rsa_hashed_import, .ecdsa, .hmac => result.hash = try converted.normalizedHash(),
        .rsa_oaep => result.label = try converted.copy(converted.first),
        else => {},
    }
    // Step 11.
    return result;
}

const HashInput = union(enum) { string: []u8, object: engine.Owned };

const Converted = struct {
    realm: runtime.Context,
    hash: ?HashInput = null,
    first: ?engine.Owned = null,
    second: ?engine.Owned = null,

    fn deinit(self: *Converted) void {
        if (self.hash) |value| switch (value) {
            .string => |bytes| self.realm.allocator.free(bytes),
            .object => |owned| owned.release(),
        };
        if (self.first) |value| value.release();
        if (self.second) |value| value.release();
    }

    fn copy(self: *Converted, value: ?engine.Owned) !?[]u8 {
        const owned = value orelse return null;
        return (try engine.getCopyOfBufferSourceBytes(self.realm, owned.borrow(), self.realm.allocator)) orelse return error.TypeError;
    }

    fn normalizedHash(self: *Converted) !Hash {
        const value = self.hash orelse return error.TypeError;
        var normalized = try algorithm(self.realm, switch (value) {
            .string => |bytes| .{ .string = bytes },
            .object => |owned| .{ .object = owned.borrow() },
        }, .digest);
        defer normalized.deinit();
        return Hash.fromName(normalized.id.name());
    }
};

fn member(realm: runtime.Context, object: runtime.JSValue, name: []const u8, required: bool) !?engine.Owned {
    const value = try engine.getProperty(realm, object, name);
    if (engine.typeOf(realm, value.borrow()) == .undefined) {
        value.release();
        if (required) return error.TypeError;
        return null;
    }
    return value;
}

fn stringMember(realm: runtime.Context, object: runtime.JSValue, name: []const u8, required: bool) !?[]u8 {
    const value = (try member(realm, object, name, required)) orelse return null;
    defer value.release();
    return try engine.convertToDOMString(realm, value.borrow(), realm.allocator);
}

fn integerMember(comptime T: type, realm: runtime.Context, object: runtime.JSValue, name: []const u8, required: bool) !?T {
    const value = (try member(realm, object, name, required)) orelse return null;
    defer value.release();
    return try integers.enforceRange(T, try engine.convertToUnrestrictedDouble(realm, value.borrow()));
}

fn bufferMember(realm: runtime.Context, object: runtime.JSValue, name: []const u8, required: bool, big_integer: bool) !?engine.Owned {
    const value = (try member(realm, object, name, required)) orelse return null;
    errdefer value.release();
    if (big_integer) {
        const view = engine.describeArrayBufferView(realm, value.borrow()) orelse return error.TypeError;
        if (view.view_type != .uint8_array or view.shared) return error.TypeError;
    }
    // Validate the WebIDL member now. Discard this validation copy: step 10
    // must observe changes made by later dictionary getters, so it copies again.
    const bytes = (try engine.getCopyOfBufferSourceBytes(realm, value.borrow(), realm.allocator)) orelse return error.TypeError;
    realm.allocator.free(bytes);
    return value;
}

fn hashMember(realm: runtime.Context, object: runtime.JSValue) !HashInput {
    const value = (try member(realm, object, "hash", true)).?;
    errdefer value.release();
    if (engine.typeOf(realm, value.borrow()) == .object) return .{ .object = value };
    const text = try engine.convertToDOMString(realm, value.borrow(), realm.allocator);
    value.release();
    return .{ .string = text };
}

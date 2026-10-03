//! WebCrypto §18: recognized algorithms, operations, and parameter dictionaries.

const std = @import("std");

pub const Operation = enum { encrypt, decrypt, sign, verify, digest, derive_bits, wrap_key, unwrap_key, generate_key, import_key, export_key, get_key_length };

pub const Id = enum {
    rsa_pkcs1,
    rsa_pss,
    rsa_oaep,
    ecdsa,
    ecdh,
    ed25519,
    x25519,
    aes_ctr,
    aes_cbc,
    aes_gcm,
    aes_kw,
    hmac,
    sha1,
    sha256,
    sha384,
    sha512,
    hkdf,
    pbkdf2,

    pub fn name(self: Id) []const u8 {
        return switch (self) {
            .rsa_pkcs1 => "RSASSA-PKCS1-v1_5",
            .rsa_pss => "RSA-PSS",
            .rsa_oaep => "RSA-OAEP",
            .ecdsa => "ECDSA",
            .ecdh => "ECDH",
            .ed25519 => "Ed25519",
            .x25519 => "X25519",
            .aes_ctr => "AES-CTR",
            .aes_cbc => "AES-CBC",
            .aes_gcm => "AES-GCM",
            .aes_kw => "AES-KW",
            .hmac => "HMAC",
            .sha1 => "SHA-1",
            .sha256 => "SHA-256",
            .sha384 => "SHA-384",
            .sha512 => "SHA-512",
            .hkdf => "HKDF",
            .pbkdf2 => "PBKDF2",
        };
    }
};

pub const Dictionary = enum {
    algorithm,
    rsa_hashed_key_gen,
    rsa_hashed_import,
    rsa_pss,
    rsa_oaep,
    ec_key,
    ecdsa,
    ecdh,
    aes_ctr,
    aes_cbc,
    aes_gcm,
    aes_length,
    hmac,
    hkdf,
    pbkdf2,
};

pub const Registration = struct { id: Id, dictionary: Dictionary };

/// §18.4.4 step 5: registered algorithm for this operation, with its canonical ID.
pub fn lookup(name: []const u8, operation: Operation) error{NotSupportedError}!Registration {
    inline for (std.meta.tags(Id)) |id| {
        if (std.ascii.eqlIgnoreCase(name, id.name())) {
            const dictionary: ?Dictionary = switch (id) {
                .sha1, .sha256, .sha384, .sha512 => if (operation == .digest) .algorithm else null,
                .rsa_pkcs1, .rsa_pss, .rsa_oaep => switch (operation) {
                    .generate_key => .rsa_hashed_key_gen,
                    .import_key => .rsa_hashed_import,
                    .export_key => .algorithm,
                    .sign, .verify => if (id == .rsa_pkcs1) .algorithm else if (id == .rsa_pss) .rsa_pss else null,
                    .encrypt, .decrypt => if (id == .rsa_oaep) .rsa_oaep else null,
                    else => null,
                },
                .ecdsa, .ecdh => switch (operation) {
                    .generate_key, .import_key => .ec_key,
                    .export_key => .algorithm,
                    .sign, .verify => if (id == .ecdsa) .ecdsa else null,
                    .derive_bits => if (id == .ecdh) .ecdh else null,
                    else => null,
                },
                .ed25519, .x25519 => switch (operation) {
                    .generate_key, .import_key, .export_key => .algorithm,
                    .sign, .verify => if (id == .ed25519) .algorithm else null,
                    .derive_bits => if (id == .x25519) .ecdh else null,
                    else => null,
                },
                .aes_ctr, .aes_cbc, .aes_gcm, .aes_kw => switch (operation) {
                    .generate_key, .get_key_length => .aes_length,
                    .import_key, .export_key => .algorithm,
                    .encrypt, .decrypt => switch (id) {
                        .aes_ctr => .aes_ctr,
                        .aes_cbc => .aes_cbc,
                        .aes_gcm => .aes_gcm,
                        else => null,
                    },
                    .wrap_key, .unwrap_key => if (id == .aes_kw) .algorithm else null,
                    else => null,
                },
                .hmac => switch (operation) {
                    .generate_key, .import_key, .get_key_length => .hmac,
                    .sign, .verify, .export_key => .algorithm,
                    else => null,
                },
                .hkdf, .pbkdf2 => switch (operation) {
                    .derive_bits => if (id == .hkdf) .hkdf else .pbkdf2,
                    .import_key, .get_key_length => .algorithm,
                    else => null,
                },
            };
            return .{ .id = id, .dictionary = dictionary orelse return error.NotSupportedError };
        }
    }
    return error.NotSupportedError;
}

test "registry selects operation-specific dictionaries and canonical names" {
    const Case = struct { name: []const u8, op: Operation, id: Id, dict: Dictionary };
    const cases = [_]Case{
        .{ .name = "sHa-256", .op = .digest, .id = .sha256, .dict = .algorithm },
        .{ .name = "rSa-pSs", .op = .sign, .id = .rsa_pss, .dict = .rsa_pss },
        .{ .name = "RSA-PSS", .op = .generate_key, .id = .rsa_pss, .dict = .rsa_hashed_key_gen },
        .{ .name = "RSA-PSS", .op = .import_key, .id = .rsa_pss, .dict = .rsa_hashed_import },
        .{ .name = "RSA-OAEP", .op = .decrypt, .id = .rsa_oaep, .dict = .rsa_oaep },
        .{ .name = "rsassa-pkcs1-v1_5", .op = .verify, .id = .rsa_pkcs1, .dict = .algorithm },
        .{ .name = "ecdsa", .op = .sign, .id = .ecdsa, .dict = .ecdsa },
        .{ .name = "ECDH", .op = .generate_key, .id = .ecdh, .dict = .ec_key },
        .{ .name = "ECDH", .op = .derive_bits, .id = .ecdh, .dict = .ecdh },
        .{ .name = "Ed25519", .op = .import_key, .id = .ed25519, .dict = .algorithm },
        .{ .name = "x25519", .op = .derive_bits, .id = .x25519, .dict = .ecdh },
        .{ .name = "AES-CTR", .op = .encrypt, .id = .aes_ctr, .dict = .aes_ctr },
        .{ .name = "AES-CBC", .op = .decrypt, .id = .aes_cbc, .dict = .aes_cbc },
        .{ .name = "AES-GCM", .op = .encrypt, .id = .aes_gcm, .dict = .aes_gcm },
        .{ .name = "AES-KW", .op = .wrap_key, .id = .aes_kw, .dict = .algorithm },
        .{ .name = "AES-CBC", .op = .get_key_length, .id = .aes_cbc, .dict = .aes_length },
        .{ .name = "HMAC", .op = .import_key, .id = .hmac, .dict = .hmac },
        .{ .name = "HKDF", .op = .derive_bits, .id = .hkdf, .dict = .hkdf },
        .{ .name = "PBKDF2", .op = .derive_bits, .id = .pbkdf2, .dict = .pbkdf2 },
        .{ .name = "HKDF", .op = .get_key_length, .id = .hkdf, .dict = .algorithm },
    };
    for (cases) |case| {
        const registration = try lookup(case.name, case.op);
        try std.testing.expectEqual(case.id, registration.id);
        try std.testing.expectEqual(case.dict, registration.dictionary);
    }
}

test "recognized algorithms reject unregistered operations and aliases" {
    const Case = struct { name: []const u8, op: Operation };
    for ([_]Case{
        .{ .name = "SHA256", .op = .digest },
        .{ .name = "SHA-256 ", .op = .digest },
        .{ .name = "ſHA-256", .op = .digest },
        .{ .name = "SHA-256", .op = .generate_key },
        .{ .name = "AES-KW", .op = .encrypt },
        .{ .name = "AES-GCM", .op = .wrap_key },
        .{ .name = "RSA-OAEP", .op = .wrap_key },
        .{ .name = "HMAC", .op = .digest },
        .{ .name = "HKDF", .op = .generate_key },
        .{ .name = "PBKDF2", .op = .export_key },
        .{ .name = "X25519", .op = .sign },
        .{ .name = "Ed25519", .op = .derive_bits },
        .{ .name = "ML-KEM-768", .op = .import_key },
    }) |case| {
        try std.testing.expectError(error.NotSupportedError, lookup(case.name, case.op));
    }
}

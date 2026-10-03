//! WebCrypto asymmetric key generation and RFC-defined interchange formats.

const std = @import("std");
const keys = @import("key.zig");
const jwk = @import("jwk.zig");
const ec = @import("ec.zig");
const okp = @import("okp.zig");
const rsa = @import("rsa.zig");
const der = @import("der.zig");
const formats = @import("key_formats.zig");
const Id = @import("registry.zig").Id;

pub fn isAsymmetric(id: Id) bool {
    return switch (id) {
        .ecdsa, .ecdh, .ed25519, .x25519, .rsa_pkcs1, .rsa_pss, .rsa_oaep => true,
        else => false,
    };
}

fn isEc(id: Id) bool {
    return id == .ecdsa or id == .ecdh;
}
fn isRsa(id: Id) bool {
    return id == .rsa_pkcs1 or id == .rsa_pss or id == .rsa_oaep;
}

fn allowed(id: Id, kind: keys.Kind) !keys.Usages {
    return switch (id) {
        .ecdsa, .ed25519, .rsa_pkcs1, .rsa_pss => if (kind == .private) keys.Usages.initOne(.sign) else keys.Usages.initOne(.verify),
        .ecdh, .x25519 => if (kind == .private) keys.Usages.initMany(&.{ .deriveKey, .deriveBits }) else keys.Usages.initEmpty(),
        .rsa_oaep => if (kind == .private) keys.Usages.initMany(&.{ .decrypt, .unwrapKey }) else keys.Usages.initMany(&.{ .encrypt, .wrapKey }),
        else => error.NotSupportedError,
    };
}

fn checkUsages(usages: keys.Usages, permitted: keys.Usages) !void {
    var iterator = usages.iterator();
    while (iterator.next()) |usage| if (!permitted.contains(usage)) return error.SyntaxError;
}

fn intersection(left: keys.Usages, right: keys.Usages) keys.Usages {
    var result = keys.Usages.initEmpty();
    var iterator = left.iterator();
    while (iterator.next()) |usage| if (right.contains(usage)) {
        result.insert(usage);
    };
    return result;
}

pub fn generate(allocator: std.mem.Allocator, io: std.Io, algorithm: keys.Algorithm, extractable: bool, usages: keys.Usages) !keys.Pair {
    // §§23.7.3/24.4.1/25.3.3/26.3.2 step 1: validate all requested usages.
    const public_usages = try allowed(algorithm.id, .public);
    const private_usages = try allowed(algorithm.id, .private);
    var union_usages = public_usages;
    var iterator = private_usages.iterator();
    while (iterator.next()) |usage| union_usages.insert(usage);
    try checkUsages(usages, union_usages);
    // Step 2: CSPRNG key generation. Only scalar/seed bytes survive this call.
    const secret = if (isRsa(algorithm.id))
        try rsa.generateSecret(allocator, algorithm.modulus_length orelse return error.TypeError, algorithm.public_exponent orelse return error.TypeError)
    else if (isEc(algorithm.id))
        try ec.generateSecret(allocator, io, algorithm.named_curve orelse return error.NotSupportedError)
    else blk: {
        const seed = try allocator.alloc(u8, 32);
        errdefer erase(allocator, seed);
        io.randomSecure(seed) catch return error.OperationError;
        break :blk seed;
    };
    defer erase(allocator, secret);
    const public = try publicBytes(allocator, algorithm, secret);
    defer erase(allocator, public);
    // Remaining generation steps: public extractability is always true;
    // each half receives the intersection of requested and permitted usages.
    var public_key = try keys.Slots.init(allocator, .public, true, algorithm, intersection(usages, public_usages), public);
    errdefer public_key.deinit();
    const private_key = try keys.Slots.init(allocator, .private, extractable, algorithm, intersection(usages, private_usages), secret);
    return .{ .public_key = public_key, .private_key = private_key };
}

pub fn importKey(allocator: std.mem.Allocator, format: keys.Format, algorithm: keys.Algorithm, bytes: []const u8, dictionary: ?jwk.Data, extractable: bool, usages: keys.Usages) !keys.Slots {
    if (!isAsymmetric(algorithm.id)) return error.NotSupportedError;
    if (isEc(algorithm.id) and algorithm.named_curve == null) return error.NotSupportedError;
    if (format == .unsupported or (isRsa(algorithm.id) and format == .raw)) return error.NotSupportedError;
    const kind: keys.Kind = switch (format) {
        .pkcs8 => .private,
        .jwk => if ((dictionary orelse return error.DataError).d != null) .private else .public,
        else => .public,
    };
    // The first step of each format's import algorithm checks usages.
    try checkUsages(usages, try allowed(algorithm.id, kind));
    if (isRsa(algorithm.id)) return importRsa(allocator, format, algorithm, bytes, dictionary, kind, extractable, usages);
    const material = switch (format) {
        .raw => try normalizePublic(allocator, algorithm, bytes),
        .spki => blk: {
            const envelope = try formats.parseSpki(bytes);
            try checkEnvelope(algorithm, envelope);
            break :blk try normalizePublic(allocator, algorithm, envelope.material);
        },
        .pkcs8 => blk: {
            const envelope = try formats.parsePkcs8(bytes);
            try checkEnvelope(algorithm, envelope);
            if (isEc(algorithm.id)) {
                const decoded = try formats.parseEcPrivate(envelope.material, algorithm.named_curve.?);
                const public = try publicBytes(allocator, algorithm, decoded.secret);
                defer erase(allocator, public);
                if (decoded.public) |point| {
                    const normalized = try normalizePublic(allocator, algorithm, point);
                    defer erase(allocator, normalized);
                    if (!std.mem.eql(u8, public, normalized)) return error.DataError;
                }
                break :blk try allocator.dupe(u8, decoded.secret);
            }
            // RFC 8410 CurvePrivateKey is itself an OCTET STRING inside PKCS8.
            var inner: der.Reader = .{ .remaining = envelope.material };
            const secret = try inner.read(4);
            try inner.finish();
            if (secret.len != 32) return error.DataError;
            break :blk try allocator.dupe(u8, secret);
        },
        .jwk => try importJwkMaterial(allocator, algorithm, dictionary.?, extractable, usages),
        .unsupported => unreachable,
    };
    defer erase(allocator, material);
    // Final import steps create internal slots, independent of exported objects.
    return keys.Slots.init(allocator, kind, extractable, algorithm, usages, material);
}

/// Returns JSON UTF-8 for JWK and DER/raw bytes for the binary formats.
pub fn exportKey(allocator: std.mem.Allocator, key: *const keys.Slots, format: keys.Format) ![]u8 {
    // Each algorithm's Export Key step 3 branches on format before key type.
    if (format == .unsupported or (isRsa(key.algorithm.id) and format == .raw)) return error.NotSupportedError;
    if ((format == .raw or format == .spki) and key.kind != .public) return error.InvalidAccessError;
    if (format == .pkcs8 and key.kind != .private) return error.InvalidAccessError;
    if (isRsa(key.algorithm.id)) {
        // §§20.9.5/21.4.5/22.4.5: rsaEncryption with explicit NULL parameters.
        const parameters: formats.Element = .{ .tag = 5, .content = "" };
        return switch (format) {
            .spki => formats.spki(allocator, formats.Oid.rsa, parameters, key.material),
            .pkcs8 => formats.pkcs8(allocator, formats.Oid.rsa, parameters, key.material),
            .jwk => exportRsaJwk(allocator, key),
            .raw, .unsupported => unreachable,
        };
    }
    const identifier = if (isEc(key.algorithm.id)) formats.Oid.ec else if (key.algorithm.id == .ed25519) formats.Oid.ed25519 else formats.Oid.x25519;
    const parameters: ?formats.Element = if (isEc(key.algorithm.id)) .{ .tag = 6, .content = formats.Oid.curve(key.algorithm.named_curve.?) } else null;
    return switch (format) {
        .raw => allocator.dupe(u8, key.material),
        .spki => formats.spki(allocator, identifier, parameters, key.material),
        .pkcs8 => blk: {
            const inner = if (isEc(key.algorithm.id)) inner: {
                const public = try publicBytes(allocator, key.algorithm, key.material);
                defer erase(allocator, public);
                break :inner try formats.ecPrivate(allocator, key.algorithm.named_curve.?, key.material, public);
            } else try der.encode(allocator, 4, &.{key.material});
            defer erase(allocator, inner);
            break :blk try formats.pkcs8(allocator, identifier, parameters, inner);
        },
        .jwk => exportJwk(allocator, key),
        .unsupported => unreachable,
    };
}

fn checkEnvelope(algorithm: keys.Algorithm, envelope: formats.Envelope) !void {
    // EC imports: id-ecPublicKey and matching namedCurve are mandatory.
    // RFC 8410 imports: the exact OKP identifier and ABSENT parameters.
    if (isEc(algorithm.id)) {
        if (!std.mem.eql(u8, envelope.oid, formats.Oid.ec)) return error.DataError;
        const parameters = envelope.parameters orelse return error.DataError;
        if (parameters.tag != 6 or !std.mem.eql(u8, parameters.content, formats.Oid.curve(algorithm.named_curve.?))) return error.DataError;
    } else {
        const expected = if (algorithm.id == .ed25519) formats.Oid.ed25519 else formats.Oid.x25519;
        if (!std.mem.eql(u8, envelope.oid, expected) or envelope.parameters != null) return error.DataError;
    }
}

fn publicBytes(allocator: std.mem.Allocator, algorithm: keys.Algorithm, secret: []const u8) ![]u8 {
    if (isRsa(algorithm.id)) return rsa.publicKey(allocator, secret);
    if (isEc(algorithm.id)) return ec.publicKey(allocator, algorithm.named_curve.?, secret);
    return allocator.dupe(u8, &(try okp.publicKey(algorithm.id, secret)));
}

fn importRsa(allocator: std.mem.Allocator, format: keys.Format, algorithm: keys.Algorithm, bytes: []const u8, dictionary: ?jwk.Data, kind: keys.Kind, extractable: bool, usages: keys.Usages) !keys.Slots {
    // §§20.9.4/21.4.4/22.4.4: usages were checked before format parsing.
    const material = if (format == .jwk)
        try importRsaJwk(allocator, algorithm, dictionary.?, extractable, usages)
    else blk: {
        const envelope = if (format == .spki) try formats.parseSpki(bytes) else try formats.parsePkcs8(bytes);
        if (!std.mem.eql(u8, envelope.oid, formats.Oid.rsa)) return error.DataError;
        // The import algorithms check only the OID. §14.3.9 says fields not
        // explicitly referenced by the algorithm do not affect import.
        break :blk try rsa.importDer(allocator, envelope.material, kind == .private);
    };
    defer erase(allocator, material);
    const parts = try rsa.components(material, kind == .private);
    var metadata = algorithm;
    // Final import steps obtain modulusLength and publicExponent from the key.
    metadata.modulus_length = try rsa.bitLength(parts.n);
    metadata.public_exponent = parts.e;
    return keys.Slots.init(allocator, kind, extractable, metadata, usages, material);
}

fn rsaAlgorithmName(algorithm: keys.Algorithm) ![]const u8 {
    const hash = algorithm.hash orelse return error.NotSupportedError;
    return switch (algorithm.id) {
        .rsa_pkcs1 => switch (hash) {
            .sha1 => "RS1",
            .sha256 => "RS256",
            .sha384 => "RS384",
            .sha512 => "RS512",
        },
        .rsa_pss => switch (hash) {
            .sha1 => "PS1",
            .sha256 => "PS256",
            .sha384 => "PS384",
            .sha512 => "PS512",
        },
        .rsa_oaep => switch (hash) {
            .sha1 => "RSA-OAEP",
            .sha256 => "RSA-OAEP-256",
            .sha384 => "RSA-OAEP-384",
            .sha512 => "RSA-OAEP-512",
        },
        else => error.NotSupportedError,
    };
}

fn importRsaJwk(allocator: std.mem.Allocator, algorithm: keys.Algorithm, data: jwk.Data, extractable: bool, usages: keys.Usages) ![]u8 {
    if (!std.mem.eql(u8, data.kty orelse "", "RSA")) return error.DataError;
    try jwk.validate(data, usages, extractable, if (algorithm.id == .rsa_oaep) "enc" else "sig", try rsaAlgorithmName(algorithm));
    // RFC 7518 §6.3: Base64urlUInt is the minimal unsigned big-endian form.
    // §6.3.2.7 forbids use of a multi-prime key by a two-prime implementation.
    if (data.d != null and data.oth != null) return error.DataError;
    var storage: [8]?[]u8 = @splat(null);
    defer for (storage) |value| if (value) |bytes| erase(allocator, bytes);
    inline for (.{ "n", "e", "d", "p", "q", "dp", "dq", "qi" }, 0..) |field, index| {
        if (index < 2 or data.d != null) {
            if (@field(data, field)) |encoded| {
                storage[index] = try jwk.decode(allocator, encoded);
                const decoded = storage[index].?;
                if (decoded.len == 0 or decoded[0] == 0) return error.DataError;
            }
        }
    }
    return rsa.importComponents(allocator, .{
        .n = storage[0] orelse return error.DataError,
        .e = storage[1] orelse return error.DataError,
        .d = storage[2],
        .p = storage[3],
        .q = storage[4],
        .dp = storage[5],
        .dq = storage[6],
        .qi = storage[7],
    });
}

fn exportRsaJwk(allocator: std.mem.Allocator, key: *const keys.Slots) ![]u8 {
    const parts = try rsa.components(key.material, key.kind == .private);
    var data: jwk.Data = .{ .kty = "RSA", .alg = try rsaAlgorithmName(key.algorithm), .ext = key.extractable };
    var storage: [8]?[]u8 = @splat(null);
    defer for (storage) |value| if (value) |bytes| erase(allocator, bytes);
    inline for (.{ "n", "e", "d", "p", "q", "dp", "dq", "qi" }, 0..) |field, index| {
        const part: ?[]const u8 = @field(parts, field);
        if (part) |bytes| {
            storage[index] = try jwk.encode(allocator, bytes);
            @field(data, field) = storage[index];
        }
    }
    var operations: [std.meta.tags(keys.Usage).len][]const u8 = undefined;
    var count: usize = 0;
    var iterator = key.usages.iterator();
    while (iterator.next()) |usage| : (count += 1) operations[count] = @tagName(usage);
    data.key_ops = operations[0..count];
    return std.json.Stringify.valueAlloc(allocator, data, .{ .emit_null_optional_fields = false });
}

fn normalizePublic(allocator: std.mem.Allocator, algorithm: keys.Algorithm, bytes: []const u8) ![]u8 {
    if (isEc(algorithm.id)) return ec.normalizePublic(allocator, algorithm.named_curve.?, bytes);
    // §§25.3.4/26.3.3 raw import only checks the length; weak OKP public keys
    // are rejected by verify/deriveBits, not by the import operation.
    if (bytes.len != 32) return error.DataError;
    return allocator.dupe(u8, bytes);
}

fn importJwkMaterial(allocator: std.mem.Allocator, algorithm: keys.Algorithm, data: jwk.Data, extractable: bool, usages: keys.Usages) ![]u8 {
    const elliptic = isEc(algorithm.id);
    const signature = algorithm.id == .ecdsa or algorithm.id == .ed25519;
    if (!std.mem.eql(u8, data.kty orelse "", if (elliptic) "EC" else "OKP")) return error.DataError;
    const curve = if (elliptic) algorithm.named_curve.?.name() else algorithm.id.name();
    if (!std.mem.eql(u8, data.crv orelse "", curve)) return error.DataError;
    // §§23.7.4/25.3.4 JWK alg checks. ECDH/X25519 do not check alg.
    if (data.alg) |name| {
        if (algorithm.id == .ecdsa) {
            const expected = switch (algorithm.named_curve.?) {
                .p256 => "ES256",
                .p384 => "ES384",
                .p521 => "ES512",
            };
            if (!std.mem.eql(u8, name, expected)) return error.DataError;
        } else if (algorithm.id == .ed25519 and !std.mem.eql(u8, name, "Ed25519") and !std.mem.eql(u8, name, "EdDSA")) return error.DataError;
    }
    try jwk.validate(data, usages, extractable, if (signature) "sig" else "enc", null);
    const x = try jwk.decode(allocator, data.x orelse return error.DataError);
    defer erase(allocator, x);
    const raw = if (elliptic) blk: {
        const y = try jwk.decode(allocator, data.y orelse return error.DataError);
        defer erase(allocator, y);
        const n = ec.byteLength(algorithm.named_curve.?);
        if (x.len != n or y.len != n) return error.DataError;
        const point = try allocator.alloc(u8, 1 + 2 * n);
        point[0] = 4;
        @memcpy(point[1..][0..n], x);
        @memcpy(point[1 + n ..], y);
        break :blk point;
    } else try allocator.dupe(u8, x);
    defer erase(allocator, raw);
    const public = try normalizePublic(allocator, algorithm, raw);
    defer erase(allocator, public);
    if (data.d) |encoded| {
        const secret = try jwk.decode(allocator, encoded);
        errdefer erase(allocator, secret);
        // RFC 7518 §6.2.2 / RFC 8037 §2: the private and public components
        // describe one key pair. Validate the scalar/seed before retaining it.
        const derived = try publicBytes(allocator, algorithm, secret);
        defer erase(allocator, derived);
        if (!std.mem.eql(u8, derived, public)) return error.DataError;
        return secret;
    }
    return allocator.dupe(u8, public);
}

fn exportJwk(allocator: std.mem.Allocator, key: *const keys.Slots) ![]u8 {
    const public = if (key.kind == .private) try publicBytes(allocator, key.algorithm, key.material) else try allocator.dupe(u8, key.material);
    defer erase(allocator, public);
    const elliptic = isEc(key.algorithm.id);
    const n = if (elliptic) ec.byteLength(key.algorithm.named_curve.?) else 32;
    const x = try jwk.encode(allocator, if (elliptic) public[1..][0..n] else public);
    defer erase(allocator, x);
    const y = if (elliptic) try jwk.encode(allocator, public[1 + n ..]) else null;
    defer if (y) |bytes| erase(allocator, bytes);
    const d = if (key.kind == .private) try jwk.encode(allocator, key.material) else null;
    defer if (d) |bytes| erase(allocator, bytes);
    var operations: [std.meta.tags(keys.Usage).len][]const u8 = undefined;
    var count: usize = 0;
    var iterator = key.usages.iterator();
    while (iterator.next()) |usage| : (count += 1) operations[count] = @tagName(usage);
    // Export JWK steps: EC and X25519 omit alg; Ed25519 emits Ed25519.
    const data: jwk.Data = .{
        .kty = if (elliptic) "EC" else "OKP",
        .crv = if (elliptic) key.algorithm.named_curve.?.name() else key.algorithm.id.name(),
        .alg = if (key.algorithm.id == .ed25519) "Ed25519" else null,
        .x = x,
        .y = y,
        .d = d,
        .ext = key.extractable,
        .key_ops = operations[0..count],
    };
    return std.json.Stringify.valueAlloc(allocator, data, .{ .emit_null_optional_fields = false });
}

fn erase(allocator: std.mem.Allocator, bytes: []u8) void {
    std.crypto.secureZero(u8, bytes);
    allocator.free(bytes);
}

fn hex(comptime text: []const u8) [text.len / 2]u8 {
    var result: [text.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, text) catch unreachable;
    return result;
}

test "RFC 8410 Ed25519 PKCS8 and SPKI export preserve RFC 8032 key bytes" {
    const a = std.testing.allocator;
    const private = hex("302e020100300506032b6570042204209d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60");
    const public = hex("302a300506032b6570032100d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
    var key = try importKey(a, .pkcs8, .{ .id = .ed25519 }, &private, null, true, keys.Usages.initOne(.sign));
    defer key.deinit();
    const exported_private = try exportKey(a, &key, .pkcs8);
    defer a.free(exported_private);
    try std.testing.expectEqualSlices(u8, &private, exported_private);
    const json = try exportKey(a, &key, .jwk);
    defer a.free(json);
    const parsed = try std.json.parseFromSlice(jwk.Data, a, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("OKP", parsed.value.kty.?);
    try std.testing.expectEqualStrings("Ed25519", parsed.value.alg.?);
    try std.testing.expectEqualStrings("Ed25519", parsed.value.crv.?);
    try std.testing.expectEqualStrings("nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A", parsed.value.d.?);
    try std.testing.expectEqualStrings("11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo", parsed.value.x.?);
    var imported_public = try importKey(a, .spki, .{ .id = .ed25519 }, &public, null, true, keys.Usages.initOne(.verify));
    defer imported_public.deinit();
    const exported_public = try exportKey(a, &imported_public, .spki);
    defer a.free(exported_public);
    try std.testing.expectEqualSlices(u8, &public, exported_public);
    try std.testing.expectError(error.InvalidAccessError, exportKey(a, &key, .raw));
    try std.testing.expectError(error.InvalidAccessError, exportKey(a, &imported_public, .pkcs8));
}

test "OKP DER rejects parameters, trailing data, wrong versions and malformed private octets" {
    const a = std.testing.allocator;
    const public = hex("302a300506032b656e0321008520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a");
    const with_null = hex("302c300706032b656e05000321008520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a");
    const private = hex("302e020100300506032b656e0422042077076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a");
    const algorithm: keys.Algorithm = .{ .id = .x25519 };
    const uses = keys.Usages.initOne(.deriveBits);
    try std.testing.expectError(error.DataError, importKey(a, .spki, algorithm, &with_null, null, true, keys.Usages.initEmpty()));
    try std.testing.expectError(error.DataError, importKey(a, .spki, algorithm, &(public ++ [_]u8{0}), null, true, keys.Usages.initEmpty()));
    var wrong_version = private;
    wrong_version[4] = 1;
    try std.testing.expectError(error.DataError, importKey(a, .pkcs8, algorithm, &wrong_version, null, true, uses));
    var wrong_inner_tag = private;
    wrong_inner_tag[14] = 3;
    try std.testing.expectError(error.DataError, importKey(a, .pkcs8, algorithm, &wrong_inner_tag, null, true, uses));
    try std.testing.expectError(error.DataError, importKey(a, .spki, .{ .id = .ed25519 }, &public, null, true, keys.Usages.initOne(.verify)));
}

fn roundtripEc(allocator: std.mem.Allocator) anyerror!void {
    const secret = hex("c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721");
    const public = hex("0460fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb67903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299");
    const x = try jwk.encode(allocator, public[1..33]);
    defer allocator.free(x);
    const y = try jwk.encode(allocator, public[33..]);
    defer allocator.free(y);
    const d = try jwk.encode(allocator, &secret);
    defer allocator.free(d);
    const algorithm: keys.Algorithm = .{ .id = .ecdsa, .named_curve = .p256 };
    const data: jwk.Data = .{ .kty = "EC", .crv = "P-256", .alg = "ES256", .x = x, .y = y, .d = d, .ext = true, .key_ops = &.{"sign"} };
    var key = try importKey(allocator, .jwk, algorithm, "", data, true, keys.Usages.initOne(.sign));
    defer key.deinit();
    try std.testing.expectEqualSlices(u8, &secret, key.material);
    const pkcs8 = try exportKey(allocator, &key, .pkcs8);
    defer allocator.free(pkcs8);
    var copy = try importKey(allocator, .pkcs8, algorithm, pkcs8, null, true, keys.Usages.initOne(.sign));
    defer copy.deinit();
    try std.testing.expectEqualSlices(u8, key.material, copy.material);
    var public_key = try importKey(allocator, .raw, algorithm, &public, null, true, keys.Usages.initOne(.verify));
    defer public_key.deinit();
    const spki = try exportKey(allocator, &public_key, .spki);
    defer allocator.free(spki);
    var public_copy = try importKey(allocator, .spki, algorithm, spki, null, true, keys.Usages.initOne(.verify));
    defer public_copy.deinit();
    try std.testing.expectEqualSlices(u8, &public, public_copy.material);
}

test "EC JWK, PKCS8 and SPKI ownership survives every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, roundtripEc, .{});
}

test "asymmetric imports validate usages and reject inconsistent JWK private/public pairs" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.SyntaxError, importKey(a, .raw, .{ .id = .x25519 }, "", null, true, keys.Usages.initOne(.deriveBits)));
    try std.testing.expectError(error.SyntaxError, importKey(a, .pkcs8, .{ .id = .ed25519 }, "", null, true, keys.Usages.initOne(.verify)));
    const data: jwk.Data = .{ .kty = "OKP", .crv = "Ed25519", .d = "nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A", .x = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" };
    try std.testing.expectError(error.DataError, importKey(a, .jwk, .{ .id = .ed25519 }, "", data, true, keys.Usages.initOne(.sign)));
    // Raw OKP public keys are length-checked here; point validation is deferred
    // until verification/agreement by §§25.3.4/26.3.3's raw import steps.
    var public = try importKey(a, .raw, .{ .id = .ed25519 }, &([_]u8{0} ** 32), null, true, keys.Usages.initOne(.verify));
    defer public.deinit();
    try std.testing.expectEqual(keys.Kind.public, public.kind);
}

test "generated curve key pairs split usages and make public keys extractable" {
    const a = std.testing.allocator;
    const algorithms = [_]keys.Algorithm{
        .{ .id = .ed25519 },                     .{ .id = .x25519 },
        .{ .id = .ecdsa, .named_curve = .p256 }, .{ .id = .ecdh, .named_curve = .p384 },
        .{ .id = .ecdsa, .named_curve = .p521 },
    };
    for (algorithms) |algorithm| {
        if (algorithm.named_curve == .p521 and !@import("mbed.zig").available) continue;
        const signature = algorithm.id == .ed25519 or algorithm.id == .ecdsa;
        const usages = if (signature) keys.Usages.initMany(&.{ .sign, .verify }) else keys.Usages.initMany(&.{ .deriveBits, .deriveKey });
        var pair = try generate(a, std.testing.io, algorithm, false, usages);
        defer pair.public_key.deinit();
        defer pair.private_key.deinit();
        try std.testing.expect(pair.public_key.extractable);
        try std.testing.expect(!pair.private_key.extractable);
        try std.testing.expectEqual(keys.Kind.public, pair.public_key.kind);
        try std.testing.expectEqual(keys.Kind.private, pair.private_key.kind);
        try std.testing.expectEqual(@as(usize, if (signature) 1 else 0), pair.public_key.usages.count());
        try std.testing.expectEqual(@as(usize, if (signature) 1 else 2), pair.private_key.usages.count());
    }
}

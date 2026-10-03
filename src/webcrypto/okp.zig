//! WebCrypto §§25–26: Ed25519 signatures and X25519 key agreement.

const std = @import("std");
const Id = @import("registry.zig").Id;
const Ed25519 = std.crypto.sign.Ed25519;
const X25519 = std.crypto.dh.X25519;

pub fn publicKey(id: Id, secret: []const u8) ![32]u8 {
    if (secret.len != 32) return error.DataError;
    // §§25.3.3/26.3.2: derive the public half using RFC 8032 / RFC 7748.
    if (id == .x25519) return X25519.recoverPublicKey(secret[0..32].*) catch error.OperationError;
    if (id != .ed25519) return error.NotSupportedError;
    var pair = Ed25519.KeyPair.generateDeterministic(secret[0..32].*) catch return error.OperationError;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&pair));
    return pair.public_key.toBytes();
}

pub fn sign(allocator: std.mem.Allocator, secret: []const u8, message: []const u8) ![]u8 {
    if (secret.len != 32) return error.DataError;
    // §25.3.1 steps 2–3: pure Ed25519, with RFC 8032's deterministic nonce.
    var pair = Ed25519.KeyPair.generateDeterministic(secret[0..32].*) catch return error.OperationError;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&pair));
    const signature = pair.sign(message, null) catch return error.OperationError;
    return allocator.dupe(u8, &signature.toBytes());
}

pub fn verify(public: []const u8, signature: []const u8, message: []const u8) !bool {
    // §25.3.2 steps 2–3: exact signature size; reject noncanonical/small-order
    // public keys and R before checking the cofactorless verification equation.
    if (public.len != 32 or signature.len != 64) return false;
    const key = Ed25519.PublicKey.fromBytes(public[0..32].*) catch return false;
    const a = Ed25519.Curve.fromBytes(public[0..32].*) catch return false;
    a.clearCofactor().rejectIdentity() catch return false;
    const r = Ed25519.Curve.fromBytes(signature[0..32].*) catch return false;
    r.clearCofactor().rejectIdentity() catch return false;
    // Step 4 explicitly chooses [S]B = R + [k]A, not cofactored verification.
    Ed25519.Signature.fromBytes(signature[0..64].*).verifyStrict(message, key) catch return false;
    return true;
}

pub fn derive(allocator: std.mem.Allocator, secret: []const u8, peer: []const u8, length: ?u32) ![]u8 {
    // §26.3.1 step 4: length validation precedes the native agreement.
    const bits = length orelse 256;
    if (bits > 256) return error.OperationError;
    if (secret.len != 32 or peer.len != 32) return error.DataError;
    // Steps 7–8: RFC 7748 clamps the scalar, masks the peer's high bit and
    // rejects all-zero agreement even when the requested output is empty.
    var shared = X25519.scalarmult(secret[0..32].*, peer[0..32].*) catch return error.OperationError;
    defer std.crypto.secureZero(u8, &shared);
    if (std.crypto.timing_safe.eql([32]u8, shared, @splat(0))) return error.OperationError;
    // Step 9: the leftmost length bits, with unused low bits set to zero.
    const result = try allocator.dupe(u8, shared[0 .. (bits + 7) / 8]);
    if (bits % 8 != 0) result[result.len - 1] &= @as(u8, 0xff) << @intCast(8 - bits % 8);
    return result;
}

fn hex(comptime text: []const u8) [text.len / 2]u8 {
    var result: [text.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, text) catch unreachable;
    return result;
}

test "Ed25519 matches RFC 8032 section 7.1 test 1" {
    const secret = hex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60");
    const public = hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
    const signature = hex("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
    try std.testing.expectEqualSlices(u8, &public, &(try publicKey(.ed25519, &secret)));
    const result = try sign(std.testing.allocator, &secret, "");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, &signature, result);
    try std.testing.expect(try verify(&public, &signature, ""));
    try std.testing.expect(!try verify(&public, &signature, "changed"));
    try std.testing.expect(!try verify(&public, signature[0..63], ""));
}

test "Ed25519 rejects small-order points and noncanonical signatures" {
    const identity = [_]u8{1} ++ [_]u8{0} ** 31;
    const identity_signature = identity ++ [_]u8{0} ** 32;
    try std.testing.expect(!try verify(&identity, &identity_signature, ""));
    const order_four = [_]u8{0} ** 32;
    try std.testing.expect(!try verify(&order_four, &identity_signature, ""));
    const public = hex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
    var signature = hex("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
    @memset(signature[32..], 0xff);
    try std.testing.expect(!try verify(&public, &signature, ""));
}

test "X25519 matches RFC 7748 section 6.1 including bit truncation" {
    const secret = hex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a");
    const public = hex("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a");
    const peer = hex("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f");
    const expected = hex("4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742");
    try std.testing.expectEqualSlices(u8, &public, &(try publicKey(.x25519, &secret)));
    const result = try derive(std.testing.allocator, &secret, &peer, null);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualSlices(u8, &expected, result);
    const truncated = try derive(std.testing.allocator, &secret, &peer, 13);
    defer std.testing.allocator.free(truncated);
    try std.testing.expectEqualSlices(u8, &.{ 0x4a, 0x58 }, truncated);
    const empty = try derive(std.testing.allocator, &secret, &peer, 0);
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    try std.testing.expectError(error.OperationError, derive(std.testing.allocator, &secret, &peer, 257));
    // WebCrypto §26.3.1 step 8 rejects all-zero agreement before truncation.
    try std.testing.expectError(error.OperationError, derive(std.testing.allocator, &secret, &([_]u8{0} ** 32), 0));
}

test "OKP operations reject malformed native key lengths" {
    try std.testing.expectError(error.DataError, publicKey(.ed25519, ""));
    try std.testing.expectError(error.DataError, publicKey(.x25519, &([_]u8{1} ** 33)));
}

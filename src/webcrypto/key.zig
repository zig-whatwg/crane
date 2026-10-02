//! WebCrypto §9 and §13.3: native key slots, distinct from cached JS objects.

const std = @import("std");
const Hash = @import("hash.zig").Hash;
const Id = @import("registry.zig").Id;

pub const Kind = enum { public, private, secret };
pub const Curve = enum {
    p256,
    p384,
    p521,

    pub fn name(self: Curve) []const u8 {
        return switch (self) {
            .p256 => "P-256",
            .p384 => "P-384",
            .p521 => "P-521",
        };
    }
};

// Order is WebCrypto's recognized key usages, including the installed modern IDL.
pub const Usage = enum { encrypt, decrypt, sign, verify, deriveKey, deriveBits, wrapKey, unwrapKey, encapsulateKey, encapsulateBits, decapsulateKey, decapsulateBits };
pub const Usages = std.EnumSet(Usage);

/// Convert recognized WebIDL enum strings and normalize duplicate usages.
pub fn usagesFromStrings(values: []const []const u8) error{TypeError}!Usages {
    // §9 usages normalization: the intersection in recognized-usage order.
    var result = Usages.initEmpty();
    for (values) |value| result.insert(std.meta.stringToEnum(Usage, value) orelse return error.TypeError);
    return result;
}

/// Native metadata. `public_exponent` is borrowed on input, owned inside Slots.
pub const Algorithm = struct {
    id: Id,
    hash: ?Hash = null,
    length: ?u32 = null,
    modulus_length: ?u32 = null,
    public_exponent: ?[]const u8 = null,
    named_curve: ?Curve = null,
};

/// Slots owned by one CryptoKey. Algorithms consume a const view, never a getter.
pub const Slots = struct {
    allocator: std.mem.Allocator,
    kind: Kind,
    extractable: bool,
    algorithm: Algorithm,
    usages: Usages,
    material: []const u8,

    /// Make independent copies of key material and variable-size metadata.
    pub fn init(allocator: std.mem.Allocator, kind: Kind, extractable: bool, algorithm: Algorithm, usages: Usages, material: []const u8) !Slots {
        const owned_material = try allocator.dupe(u8, material);
        errdefer {
            std.crypto.secureZero(u8, owned_material);
            allocator.free(owned_material);
        }
        var owned_algorithm = algorithm;
        if (algorithm.public_exponent) |exponent| owned_algorithm.public_exponent = try allocator.dupe(u8, exponent);
        return .{ .allocator = allocator, .kind = kind, .extractable = extractable, .algorithm = owned_algorithm, .usages = usages, .material = owned_material };
    }

    /// Erase key bytes before releasing their allocation.
    pub fn deinit(self: *Slots) void {
        std.crypto.secureZero(u8, @constCast(self.material));
        self.allocator.free(self.material);
        if (self.algorithm.public_exponent) |exponent| self.allocator.free(exponent);
        self.* = undefined;
    }
};

test "usages normalize duplicates in recognized order, with case-sensitive enum conversion" {
    var usages = try usagesFromStrings(&.{ "verify", "sign", "verify", "deriveBits", "encrypt" });
    var iterator = usages.iterator();
    for ([_]Usage{ .encrypt, .sign, .verify, .deriveBits }) |expected| {
        try std.testing.expectEqual(expected, iterator.next().?);
    }
    try std.testing.expect(iterator.next() == null);
    try std.testing.expect((try usagesFromStrings(&.{})).count() == 0);
    for ([_][]const u8{ "Sign", "sign ", "", "unknown" }) |value| {
        try std.testing.expectError(error.TypeError, usagesFromStrings(&.{value}));
    }
    // Known but unsupported modern usages reach an algorithm's SyntaxError check.
    try std.testing.expect((try usagesFromStrings(&.{"encapsulateKey"})).contains(.encapsulateKey));
}

fn checkOwnedSlots(allocator: std.mem.Allocator) anyerror!void {
    var material = [_]u8{ 1, 2, 3, 4 };
    var exponent = [_]u8{ 1, 0, 1 };
    var slots = try Slots.init(allocator, .private, false, .{
        .id = .rsa_pss,
        .hash = .sha256,
        .modulus_length = 2048,
        .public_exponent = &exponent,
    }, Usages.initOne(.sign), &material);
    defer slots.deinit();
    @memset(&material, 0);
    @memset(&exponent, 0);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, slots.material);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 1 }, slots.algorithm.public_exponent.?);
    try std.testing.expectEqual(Kind.private, slots.kind);
    try std.testing.expect(!slots.extractable);
    try std.testing.expect(slots.usages.contains(.sign));
    try std.testing.expect(!slots.usages.contains(.verify));
}

test "key slots own independent material and exponent, including allocation failure paths" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkOwnedSlots, .{});
}

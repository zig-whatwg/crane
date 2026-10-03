//! WebCrypto §9, RFC 5280 SPKI and RFC 5208 PrivateKeyInfo envelopes.

const std = @import("std");
const keys = @import("key.zig");
const der = @import("der.zig");

pub const Oid = struct {
    pub const rsa = "\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01";
    pub const ec = "\x2a\x86\x48\xce\x3d\x02\x01";
    pub const p256 = "\x2a\x86\x48\xce\x3d\x03\x01\x07";
    pub const p384 = "\x2b\x81\x04\x00\x22";
    pub const p521 = "\x2b\x81\x04\x00\x23";
    pub const ed25519 = "\x2b\x65\x70";
    pub const x25519 = "\x2b\x65\x6e";

    pub fn curve(value: keys.Curve) []const u8 {
        return switch (value) {
            .p256 => p256,
            .p384 => p384,
            .p521 => p521,
        };
    }
};

pub const Element = struct { tag: u8, content: []const u8 };
pub const Envelope = struct { oid: []const u8, parameters: ?Element, material: []const u8 };
pub const EcPrivate = struct { secret: []const u8, public: ?[]const u8 };

pub fn parseSpki(bytes: []const u8) !Envelope {
    // RFC 5280 §4.1: AlgorithmIdentifier followed by one public-key BIT STRING.
    var reader = try der.sequence(bytes);
    var result = try algorithmIdentifier(try reader.read(0x30));
    result.material = try reader.bits();
    try reader.finish();
    return result;
}

pub fn parsePkcs8(bytes: []const u8) !Envelope {
    // RFC 5208 §5: version 0, algorithm, private octets, optional attributes.
    var reader = try der.sequence(bytes);
    if (!std.mem.eql(u8, try reader.integer(), &.{0})) return error.DataError;
    var result = try algorithmIdentifier(try reader.read(0x30));
    result.material = try reader.read(4);
    if (reader.remaining.len != 0) {
        const attributes = try reader.read(0xa0);
        try sortedElements(attributes);
        var list: der.Reader = .{ .remaining = attributes };
        while (list.remaining.len != 0) {
            var attribute: der.Reader = .{ .remaining = try list.read(0x30) };
            try oid(try attribute.read(6));
            const values = try attribute.read(0x31);
            try sortedElements(values);
            try validateContents(values);
            try attribute.finish();
        }
    }
    try reader.finish();
    return result;
}

pub fn parseEcPrivate(bytes: []const u8, curve: keys.Curve) !EcPrivate {
    // RFC 5915 §3: version 1, scalar, optional named curve and public point.
    var reader = try der.sequence(bytes);
    if (!std.mem.eql(u8, try reader.integer(), &.{1})) return error.DataError;
    const secret = try reader.read(4);
    if (reader.remaining.len != 0 and reader.remaining[0] == 0xa0) {
        var parameters: der.Reader = .{ .remaining = try reader.read(0xa0) };
        if (!std.mem.eql(u8, try parameters.read(6), Oid.curve(curve))) return error.DataError;
        try parameters.finish();
    }
    var public: ?[]const u8 = null;
    if (reader.remaining.len != 0) {
        var point: der.Reader = .{ .remaining = try reader.read(0xa1) };
        public = try point.bits();
        try point.finish();
    }
    try reader.finish();
    return .{ .secret = secret, .public = public };
}

pub fn spki(allocator: std.mem.Allocator, algorithm: []const u8, parameters: ?Element, material: []const u8) ![]u8 {
    const identifier = try encodeAlgorithm(allocator, algorithm, parameters);
    defer erase(allocator, identifier);
    const public = try der.encode(allocator, 3, &.{ &.{0}, material });
    defer erase(allocator, public);
    return der.encode(allocator, 0x30, &.{ identifier, public });
}

pub fn pkcs8(allocator: std.mem.Allocator, algorithm: []const u8, parameters: ?Element, material: []const u8) ![]u8 {
    const identifier = try encodeAlgorithm(allocator, algorithm, parameters);
    defer erase(allocator, identifier);
    const private = try der.encode(allocator, 4, &.{material});
    defer erase(allocator, private);
    return der.encode(allocator, 0x30, &.{ "\x02\x01\x00", identifier, private });
}

pub fn ecPrivate(allocator: std.mem.Allocator, curve: keys.Curve, secret: []const u8, public: []const u8) ![]u8 {
    const private = try der.encode(allocator, 4, &.{secret});
    defer erase(allocator, private);
    const curve_oid = try der.encode(allocator, 6, &.{Oid.curve(curve)});
    defer erase(allocator, curve_oid);
    const parameters = try der.encode(allocator, 0xa0, &.{curve_oid});
    defer erase(allocator, parameters);
    const bits = try der.encode(allocator, 3, &.{ &.{0}, public });
    defer erase(allocator, bits);
    const point = try der.encode(allocator, 0xa1, &.{bits});
    defer erase(allocator, point);
    return der.encode(allocator, 0x30, &.{ "\x02\x01\x01", private, parameters, point });
}

fn algorithmIdentifier(bytes: []const u8) !Envelope {
    var reader: der.Reader = .{ .remaining = bytes };
    const algorithm = try reader.read(6);
    try oid(algorithm);
    var parameters: ?Element = null;
    if (reader.remaining.len != 0) {
        const encoded = reader.remaining;
        parameters = try anyElement(&reader);
        try validateContents(encoded[0 .. encoded.len - reader.remaining.len]);
    }
    try reader.finish();
    return .{ .oid = algorithm, .parameters = parameters, .material = "" };
}

fn oid(bytes: []const u8) !void {
    // X.690 §8.19: nonempty, complete, minimally encoded base-128 components.
    if (bytes.len == 0) return error.DataError;
    var at_start = true;
    for (bytes) |byte| {
        if (at_start and byte == 0x80) return error.DataError;
        at_start = byte & 0x80 == 0;
    }
    if (!at_start) return error.DataError;
}

fn anyElement(reader: *der.Reader) !Element {
    // ANY may have a high tag number. Length parsing remains in der.Reader.
    const bytes = reader.remaining;
    if (bytes.len == 0) return error.DataError;
    var end: usize = 1;
    if (bytes[0] & 0x1f == 0x1f) {
        if (end == bytes.len or bytes[end] == 0x80) return error.DataError;
        while (true) {
            if (end == bytes.len) return error.DataError;
            const byte = bytes[end];
            end += 1;
            if (byte & 0x80 == 0) break;
        }
        if (end == 2 and bytes[1] < 31) return error.DataError;
    }
    var body: der.Reader = .{ .remaining = bytes[end - 1 ..] };
    const content = try body.read(bytes[end - 1]);
    reader.remaining = body.remaining;
    return .{ .tag = bytes[0], .content = content };
}

fn sortedElements(bytes: []const u8) !void {
    // X.690 §11.6: SET OF elements sort by their complete DER encodings.
    var reader: der.Reader = .{ .remaining = bytes };
    var previous: []const u8 = "";
    while (reader.remaining.len != 0) {
        const before = reader.remaining;
        _ = try anyElement(&reader);
        const current = before[0 .. before.len - reader.remaining.len];
        if (std.mem.order(u8, previous, current) == .gt) return error.DataError;
        previous = current;
    }
}

fn validateContents(bytes: []const u8) !void {
    // Walk nested ANY values without recursion or a depth-dependent stack.
    // First check each constructed value's immediate children stay inside it;
    // then descend by advancing only past its header. Each header is read twice.
    var remaining = bytes;
    while (remaining.len != 0) {
        var reader: der.Reader = .{ .remaining = remaining };
        const element = try anyElement(&reader);
        if (element.tag == 0) return error.DataError; // DER has no end-of-content.
        if (element.tag & 0x20 != 0) {
            // X.690 §10.2: universal string/scalar types cannot use BER's
            // constructed form in DER. EXTERNAL, EMBEDDED PDV, SEQUENCE,
            // SET and unrestricted CHARACTER STRING are constructed types.
            if (element.tag & 0xc0 == 0) switch (element.tag & 0x1f) {
                8, 11, 16, 17, 29 => {},
                else => return error.DataError,
            };
            if (element.tag == 0x31) try sortedElements(element.content);
            var children: der.Reader = .{ .remaining = element.content };
            while (children.remaining.len != 0) _ = try anyElement(&children);
            const header = remaining.len - reader.remaining.len - element.content.len;
            remaining = remaining[header..];
            continue;
        }
        switch (element.tag) {
            1 => if (element.content.len != 1 or (element.content[0] != 0 and element.content[0] != 0xff)) return error.DataError,
            2, 10 => {
                const value = element.content;
                if (value.len == 0) return error.DataError;
                if (value.len > 1 and ((value[0] == 0 and value[1] & 0x80 == 0) or (value[0] == 0xff and value[1] & 0x80 != 0))) return error.DataError;
            },
            3 => {
                const value = element.content;
                if (value.len == 0 or value[0] > 7 or (value.len == 1 and value[0] != 0)) return error.DataError;
                if (value.len > 1 and value[0] != 0 and value[value.len - 1] & (@as(u8, 0xff) >> @intCast(8 - value[0])) != 0) return error.DataError;
            },
            5 => if (element.content.len != 0) return error.DataError,
            6 => try oid(element.content),
            8, 11, 16, 17, 29 => return error.DataError,
            else => {},
        }
        remaining = reader.remaining;
    }
}

fn encodeAlgorithm(allocator: std.mem.Allocator, algorithm: []const u8, parameters: ?Element) ![]u8 {
    const identifier = try der.encode(allocator, 6, &.{algorithm});
    defer erase(allocator, identifier);
    if (parameters) |parameter| {
        const encoded = try der.encode(allocator, parameter.tag, &.{parameter.content});
        defer erase(allocator, encoded);
        return der.encode(allocator, 0x30, &.{ identifier, encoded });
    }
    return der.encode(allocator, 0x30, &.{identifier});
}

fn erase(allocator: std.mem.Allocator, bytes: []u8) void {
    std.crypto.secureZero(u8, bytes);
    allocator.free(bytes);
}

test "SPKI and PKCS8 parse exact canonical DER and preserve algorithm parameters" {
    const spki_bytes = "\x30\x0d\x30\x05\x06\x03\x2b\x65\x70\x03\x04\x00abc";
    const pkcs8_bytes = "\x30\x0f\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x70\x04\x03abc";
    const public = try parseSpki(spki_bytes);
    try std.testing.expectEqualStrings(Oid.ed25519, public.oid);
    try std.testing.expect(public.parameters == null);
    try std.testing.expectEqualStrings("abc", public.material);
    const private = try parsePkcs8(pkcs8_bytes);
    try std.testing.expectEqualStrings(Oid.ed25519, private.oid);
    try std.testing.expectEqualStrings("abc", private.material);
    try std.testing.expectError(error.DataError, parseSpki(spki_bytes ++ "\x00"));
    try std.testing.expectError(error.DataError, parsePkcs8(pkcs8_bytes ++ "\x00"));
    // Version 0, canonical lengths, octet-aligned BIT STRING and valid OID.
    try std.testing.expectError(error.DataError, parsePkcs8("\x30\x0f\x02\x01\x01\x30\x05\x06\x03\x2b\x65\x70\x04\x03abc"));
    try std.testing.expectError(error.DataError, parseSpki("\x30\x81\x0d\x30\x05\x06\x03\x2b\x65\x70\x03\x04\x00abc"));
    try std.testing.expectError(error.DataError, parseSpki("\x30\x0d\x30\x05\x06\x03\x2b\x65\x70\x03\x04\x01abc"));
    try std.testing.expectError(error.DataError, parseSpki("\x30\x0d\x30\x05\x06\x03\x2b\x80\x70\x03\x04\x00abc"));
}

test "PKCS8 permits well-formed optional attributes but rejects trailing fields" {
    const prefix = "\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x70\x04\x03abc";
    const empty = try parsePkcs8("\x30\x11" ++ prefix ++ "\xa0\x00");
    try std.testing.expectEqualStrings("abc", empty.material);
    // Attribute ::= SEQUENCE { type OBJECT IDENTIFIER, values SET OF ANY }.
    const attribute = "\x30\x0a\x06\x03\x2a\x03\x04\x31\x03\x0c\x01x";
    const with_attribute = try parsePkcs8("\x30\x1d" ++ prefix ++ "\xa0\x0c" ++ attribute);
    try std.testing.expectEqualStrings("abc", with_attribute.material);
    try std.testing.expectError(error.DataError, parsePkcs8("\x30\x11" ++ prefix ++ "\xa1\x00"));
    try std.testing.expectError(error.DataError, parsePkcs8("\x30\x14" ++ prefix ++ "\xa0\x03\x02\x01\x00"));
    try std.testing.expectError(error.DataError, parsePkcs8("\x30\x13" ++ prefix ++ "\xa0\x00\xa0\x00"));
}

test "DER ANY parameters reject constructed primitive strings and accept high tags" {
    // X.690 §10.2: DER strings have primitive encodings, even inside ANY.
    try std.testing.expectError(error.DataError, parseSpki("\x30\x0f\x30\x07\x06\x03\x2b\x65\x70\x24\x00\x03\x04\x00abc"));
    // A context-specific high tag number is a valid ANY parameter.
    const parsed = try parseSpki("\x30\x10\x30\x08\x06\x03\x2b\x65\x70\x9f\x20\x00\x03\x04\x00abc");
    try std.testing.expectEqual(@as(u8, 0x9f), parsed.parameters.?.tag);
}

fn checkEnvelopeAllocation(allocator: std.mem.Allocator) anyerror!void {
    const public = try spki(allocator, Oid.ec, .{ .tag = 6, .content = Oid.p256 }, "public");
    defer allocator.free(public);
    const parsed_public = try parseSpki(public);
    try std.testing.expectEqualStrings(Oid.ec, parsed_public.oid);
    try std.testing.expectEqualStrings(Oid.p256, parsed_public.parameters.?.content);
    try std.testing.expectEqualStrings("public", parsed_public.material);
    const private = try pkcs8(allocator, Oid.ed25519, null, "private");
    defer allocator.free(private);
    try std.testing.expectEqualStrings("private", (try parsePkcs8(private)).material);
    const ec = try ecPrivate(allocator, .p384, "secret", "point");
    defer allocator.free(ec);
    const parsed_ec = try parseEcPrivate(ec, .p384);
    try std.testing.expectEqualStrings("secret", parsed_ec.secret);
    try std.testing.expectEqualStrings("point", parsed_ec.public.?);
    try std.testing.expectError(error.DataError, parseEcPrivate(ec, .p256));
}

test "DER key export erases all intermediate allocations on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, checkEnvelopeAllocation, .{});
}

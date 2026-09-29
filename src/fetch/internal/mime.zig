//! Fetch's "extract a MIME type": a header list's `Content-Type`, as the
//! MIME type it names. XMLHttpRequest's "get a response MIME type" and main
//! fetch step 19's MIME checks both read it.
//!
//! Spec: https://fetch.spec.whatwg.org/#concept-header-extract-mime-type

const std = @import("std");
const mimesniff = @import("mimesniff");
const HeaderList = @import("header_list.zig").HeaderList;

/// Fetch "extract a MIME type" from `headers`: the last `Content-Type` value
/// that parses (and is not */*), carrying an earlier same-essence value's
/// charset when it has none. Null is failure. OWNED: `deinit` it.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-extract-mime-type
pub fn extractMimeType(allocator: std.mem.Allocator, headers: *const HeaderList) !?mimesniff.MimeType {
    // 1-3. Let charset, essence and mimeType be null.
    var charset: ?[]u16 = null;
    defer if (charset) |c| allocator.free(c);
    var essence: ?[]const u16 = null;
    defer if (essence) |e| allocator.free(e);
    var mime_type: ?mimesniff.MimeType = null;
    errdefer if (mime_type) |*m| m.deinit();
    // 4. Let values be the result of getting, decoding, and splitting
    //    `Content-Type` from headers.
    // 5. If values is null, then return failure.
    const values = (try headers.getDecodeSplit(allocator, "Content-Type")) orelse return null;
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }
    // 6. For each value of values:
    for (values) |value| {
        // 1. Let temporaryMimeType be the result of parsing value.
        var temporary = (try mimesniff.parseMimeType(allocator, value)) orelse continue;
        // 2. If temporaryMimeType is failure or its essence is "*/*", then
        //    continue.
        const temporary_essence = temporary.essence(allocator) catch |err| {
            temporary.deinit();
            return err;
        };
        if (std.mem.eql(u16, temporary_essence, std.unicode.utf8ToUtf16LeStringLiteral("*/*"))) {
            allocator.free(temporary_essence);
            temporary.deinit();
            continue;
        }
        // 3. Set mimeType to temporaryMimeType.
        if (mime_type) |*m| m.deinit();
        mime_type = temporary;
        const current = &mime_type.?;
        // 4. If mimeType's essence is not essence, then:
        if (essence == null or !std.mem.eql(u16, essence.?, temporary_essence)) {
            // 1. Set charset to null.
            if (charset) |c| allocator.free(c);
            charset = null;
            // 2. If mimeType's parameters["charset"] exists, then set charset
            //    to it.
            if (parameterIndex(current.*, "charset")) |i| charset = try allocator.dupe(u16, current.parameters.entries.items()[i].value);
            // 3. Set essence to mimeType's essence.
            if (essence) |e| allocator.free(e);
            essence = temporary_essence;
        } else {
            allocator.free(temporary_essence);
            // 5. Otherwise, if mimeType's parameters["charset"] does not
            //    exist, and charset is non-null, set mimeType's
            //    parameters["charset"] to charset.
            if (parameterIndex(current.*, "charset") == null) if (charset) |c| {
                const key = try current.allocator.dupe(u16, std.unicode.utf8ToUtf16LeStringLiteral("charset"));
                errdefer current.allocator.free(key);
                const copy = try current.allocator.dupe(u16, c);
                errdefer current.allocator.free(copy);
                try current.parameters.set(key, copy);
            };
        }
    }
    // 7. If mimeType is null, then return failure.
    // 8. Return mimeType.
    return mime_type;
}

/// The index of `record`'s parameter `name` (ASCII), if it has it. (Its map
/// compares slice keys by address, so this compares the text.)
pub fn parameterIndex(record: mimesniff.MimeType, comptime name: []const u8) ?usize {
    const wide = std.unicode.utf8ToUtf16LeStringLiteral(name);
    for (record.parameters.entries.items(), 0..) |entry, i| {
        if (std.mem.eql(u16, entry.key, wide)) return i;
    }
    return null;
}

/// The essence of the MIME type "extract a MIME type" gives from `headers`,
/// as lowercase bytes (OWNED), or null for failure: what a Content-Type
/// check - nosniff, a style sheet's text/css - compares.
pub fn extractMimeEssence(allocator: std.mem.Allocator, headers: *const HeaderList) !?[]u8 {
    var extracted = (try extractMimeType(allocator, headers)) orelse return null;
    defer extracted.deinit();
    return try essenceBytes(allocator, extracted);
}

/// The essence of `mime` ("type/subtype"), as bytes - a MIME type's type
/// and subtype are HTTP token code points, all ASCII. OWNED.
pub fn essenceBytes(allocator: std.mem.Allocator, mime: mimesniff.MimeType) ![]u8 {
    const wide = try mime.essence(allocator);
    defer allocator.free(wide);
    const bytes = try allocator.alloc(u8, wide.len);
    for (wide, bytes) |c, *b| b.* = @intCast(c & 0x7F);
    return bytes;
}

fn extractedFrom(values: []const []const u8) !?[]const u8 {
    const allocator = std.testing.allocator;
    var headers = HeaderList.init(allocator);
    defer headers.deinit();
    for (values) |v| try headers.append("Content-Type", v);
    var mime = (try extractMimeType(allocator, &headers)) orelse return null;
    defer mime.deinit();
    return try mimesniff.serializeMimeTypeToBytes(allocator, mime);
}

fn expectExtracted(expected: ?[]const u8, values: []const []const u8) !void {
    const actual = try extractedFrom(values);
    defer if (actual) |a| std.testing.allocator.free(a);
    if (expected) |e| try std.testing.expectEqualStrings(e, actual orelse return error.Failure) else try std.testing.expect(actual == null);
}

test "extract a MIME type: Fetch's examples" {
    // Headers as on the network -> the serialized result.
    try expectExtracted("text/html", &.{"text/plain;charset=gbk, text/html"});
    try expectExtracted("text/html;x=y;charset=gbk", &.{"text/html;charset=gbk;a=b, text/html;x=y"});
    try expectExtracted("text/html;x=y;charset=gbk", &.{ "text/html;charset=gbk;a=b", "text/html;x=y" });
    try expectExtracted("text/html;x=y", &.{ "text/html;charset=gbk", "x/x", "text/html;x=y" });
    try expectExtracted("text/html", &.{ "text/html", "cannot-parse" });
    try expectExtracted("text/html", &.{ "text/html", "*/*" });
    try expectExtracted("text/html", &.{ "text/html", "" });
    // No Content-Type, or none that parses: failure.
    try expectExtracted(null, &.{});
    try expectExtracted(null, &.{"*/*"});
    try expectExtracted(null, &.{"bogus"});
}

test "extract a MIME type's essence: lowercase, parameters dropped, failure null" {
    const allocator = std.testing.allocator;
    const cases = [_]struct { values: []const []const u8, want: ?[]const u8 }{
        .{ .values = &.{"Text/CSS; charset=utf-8"}, .want = "text/css" },
        .{ .values = &.{"text/plain"}, .want = "text/plain" },
        .{ .values = &.{"oops"}, .want = null },
        .{ .values = &.{}, .want = null },
    };
    for (cases) |case| {
        var headers = HeaderList.init(allocator);
        defer headers.deinit();
        for (case.values) |v| try headers.append("Content-Type", v);
        const got = try extractMimeEssence(allocator, &headers);
        defer if (got) |g| allocator.free(g);
        if (case.want) |want| {
            try std.testing.expectEqualStrings(want, got.?);
        } else {
            try std.testing.expect(got == null);
        }
    }
}

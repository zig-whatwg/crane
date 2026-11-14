//! Content codings as Fetch undoes them (src/fetch/content_coding): the one
//! table, the `Content-Encoding` values it reads, its decoders - fed in
//! pieces as a body arrives - and where the browsers are more lenient than
//! the formats (each case names its Chromium / Firefox evidence in
//! src/fetch/content_coding/). Then the network: a decoded body, its
//! encoded size, and a decoding failure as a network error.
const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const cc = fetch.content_coding;
const network = fetch.network;
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const fixtures = @import("quick1b3_coding_fixtures.zig");

const Header = NetworkResponse.Header;

// ---------------------------------------------------------------------------
// The table
// ---------------------------------------------------------------------------

test "the table is what Fetch advertises: every advertised coding decodes" {
    try testing.expectEqualStrings("gzip, deflate, br, zstd", cc.acceptEncoding(true));
    try testing.expectEqualStrings("gzip, deflate", cc.acceptEncoding(false));
    var names = std.mem.splitSequence(u8, cc.acceptEncoding(true), ", ");
    while (names.next()) |name| try testing.expect(cc.byName(name) != null);
    try testing.expectEqual(cc.Coding.gzip, cc.byName("X-GZIP").?);
    try testing.expectEqual(@as(?cc.Coding, null), cc.byName("identity"));
    try testing.expectEqual(@as(?cc.Coding, null), cc.byName("compress"));
}

fn filtered(values: []const []const u8) []const u8 {
    var headers: [4]Header = undefined;
    for (values, 0..) |value, i| headers[i] = .{ .name = "content-encoding", .value = value };
    return cc.filteredCoding(cc.headerFields(@as([]const Header, headers[0..values.len])));
}

test "HTTP-network fetch's filtered coding reads the same table" {
    try testing.expectEqualStrings("", filtered(&.{}));
    try testing.expectEqualStrings("", filtered(&.{""}));
    try testing.expectEqualStrings("zstd", filtered(&.{"zstd"}));
    try testing.expectEqualStrings("gzip", filtered(&.{"gZip "}));
    // A registered alias this user agent decodes, byte-lowercased.
    try testing.expectEqualStrings("x-gzip", filtered(&.{"X-Gzip"}));
    try testing.expectEqualStrings("@unknown", filtered(&.{"identity"}));
    try testing.expectEqualStrings("@unknown", filtered(&.{"\"gzip\""}));
    try testing.expectEqualStrings("@unknown", filtered(&.{"a-name-longer-than-any-coding"}));
    try testing.expectEqualStrings("multiple", filtered(&.{"gzip, "}));
    try testing.expectEqualStrings("multiple", filtered(&.{ "gzip", "br" }));
    // A comma inside a quoted string does not split ("get, decode, and split").
    try testing.expectEqualStrings("@unknown", filtered(&.{"\"a,b\""}));
}

fn planOf(values: []const []const u8) cc.Plan {
    var headers: [4]Header = undefined;
    for (values, 0..) |value, i| headers[i] = .{ .name = "Content-Encoding", .value = value };
    return cc.plan(cc.headerFields(@as([]const Header, headers[0..values.len])));
}

fn expectPlan(expected: []const cc.Coding, values: []const []const u8) !void {
    const p = planOf(values);
    switch (p) {
        .decode => |codings| try testing.expectEqualSlices(cc.Coding, expected, codings.slice()),
        else => return error.TestExpectedDecode,
    }
}

test "the plan: codings in header order, empty values skipped, anything unknown passes the body through" {
    try expectPlan(&.{.gzip}, &.{"gzip"});
    try expectPlan(&.{.gzip}, &.{"x-gzip"});
    try expectPlan(&.{ .gzip, .br }, &.{"gzip, br"});
    try expectPlan(&.{ .deflate, .zstd }, &.{ "deflate", "zstd" });
    try expectPlan(&.{.gzip}, &.{"gzip, "});
    try testing.expect(planOf(&.{}) == .identity);
    try testing.expect(planOf(&.{""}) == .identity);
    try testing.expect(planOf(&.{"identity"}) == .identity);
    try testing.expect(planOf(&.{"gzip, identity"}) == .identity);
    try testing.expect(planOf(&.{ "br", "foo" }) == .identity);
    try testing.expect(planOf(&.{"gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip"}) == .decode);
    try testing.expect(planOf(&.{"gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip"}) == .too_many);
    // Chromium reads every value before it counts: an unknown one passes
    // even an overlong list through.
    try testing.expect(planOf(&.{"gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,foo"}) == .identity);
}

// ---------------------------------------------------------------------------
// The decoders
// ---------------------------------------------------------------------------

/// `encoded` decoded with `codings`, pushed `chunk` bytes at a time (0:
/// whole). OWNED.
fn decode(codings: []const cc.Coding, encoded: []const u8, chunk: usize) cc.Error![]u8 {
    const decoder = try cc.Decoder.create(testing.allocator, codings);
    defer decoder.destroy();
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    var collect: cc.Collect = .{ .allocator = testing.allocator, .out = &out };
    if (chunk == 0) {
        try decoder.push(encoded, collect.sink());
    } else {
        var at: usize = 0;
        while (at < encoded.len) : (at += chunk) {
            try decoder.push(encoded[at..@min(at + chunk, encoded.len)], collect.sink());
        }
    }
    return out.toOwnedSlice(testing.allocator);
}

fn expectDecodes(expected: []const u8, codings: []const cc.Coding, encoded: []const u8, chunk: usize) !void {
    const got = try decode(codings, encoded, chunk);
    defer testing.allocator.free(got);
    try testing.expectEqual(expected.len, got.len);
    try testing.expect(std.mem.eql(u8, expected, got));
}

test "each coding decodes whole, and pushed a byte at a time" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    const cases = [_]struct { codings: []const cc.Coding, bytes: []const u8 }{
        .{ .codings = &.{.gzip}, .bytes = fixtures.small_gz },
        .{ .codings = &.{.deflate}, .bytes = fixtures.small_zlib },
        .{ .codings = &.{.br}, .bytes = fixtures.small_br },
        .{ .codings = &.{.zstd}, .bytes = fixtures.small_zst },
        .{ .codings = &.{.zstd}, .bytes = fixtures.small_check_zst },
        // "Content-Encoding: gzip, br": br was applied last, so undone first.
        .{ .codings = &.{ .gzip, .br }, .bytes = fixtures.small_gz_br },
        .{ .codings = &.{ .gzip, .gzip }, .bytes = fixtures.small_gz_gz },
    };
    for (cases) |case| {
        for ([_]usize{ 0, 1, 7, 64 }) |chunk| try expectDecodes(text, case.codings, case.bytes, chunk);
    }
}

test "large bodies decode across many DEFLATE calls, Brotli outputs and zstd blocks" {
    const text = try fixtures.big(testing.allocator);
    defer testing.allocator.free(text);
    for ([_]usize{ 0, 1000, 16384 }) |chunk| {
        try expectDecodes(text, &.{.gzip}, fixtures.big_gz, chunk);
        try expectDecodes(text, &.{.br}, fixtures.big_br, chunk);
        try expectDecodes(text, &.{.zstd}, fixtures.big_check_zst, chunk);
    }
}

test "deflate: raw DEFLATE without the zlib wrapper decodes, as Chromium and Firefox decode it" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    for ([_]usize{ 0, 1, 5 }) |chunk| try expectDecodes(text, &.{.deflate}, fixtures.small_deflate, chunk);
}

test "deflate: a wrong Adler-32 fails, a missing one does not" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    var bad = fixtures.small_zlib.*;
    bad[bad.len - 1] ^= 0x01;
    try testing.expectError(error.InvalidData, decode(&.{.deflate}, &bad, 0));
    try expectDecodes(text, &.{.deflate}, fixtures.small_zlib[0 .. fixtures.small_zlib.len - 4], 0);
}

test "gzip: the trailer is not checked, and what follows the stream is ignored" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    // A wrong CRC-32, a wrong ISIZE.
    for ([_]usize{ 8, 1 }) |from_end| {
        var bad = fixtures.small_gz.*;
        bad[bad.len - from_end] ^= 0xff;
        try expectDecodes(text, &.{.gzip}, &bad, 0);
    }
    // Junk after it, or a second member: the first member alone.
    try expectDecodes(text, &.{.gzip}, fixtures.small_gz ++ "junk after the stream", 0);
    try expectDecodes(text, &.{.gzip}, fixtures.small_gz ++ fixtures.small_gz, 3);
    // No trailer at all.
    try expectDecodes(text, &.{.gzip}, fixtures.small_gz[0 .. fixtures.small_gz.len - 8], 0);
}

test "a body that stops early is not an error: what decoded so far is the body" {
    const text = try fixtures.big(testing.allocator);
    defer testing.allocator.free(text);
    const cases = [_]struct { coding: cc.Coding, bytes: []const u8 }{
        .{ .coding = .gzip, .bytes = fixtures.big_gz },
        .{ .coding = .br, .bytes = fixtures.big_br },
        .{ .coding = .zstd, .bytes = fixtures.big_check_zst },
    };
    for (cases) |case| {
        const got = try decode(&.{case.coding}, case.bytes[0 .. case.bytes.len * 2 / 3], 4096);
        defer testing.allocator.free(got);
        try testing.expect(got.len > 0 and got.len < text.len);
        try testing.expect(std.mem.startsWith(u8, text, got));
    }
}

test "bytes that are not the coding fail" {
    try testing.expectError(error.InvalidData, decode(&.{.gzip}, "not actually gzip", 0));
    try testing.expectError(error.InvalidData, decode(&.{.zstd}, "not actually zstd", 0));
    // A partial magic that can start no frame fails at once.
    try testing.expectError(error.InvalidData, decode(&.{.zstd}, "no", 0));
    try testing.expectError(error.InvalidData, decode(&.{.deflate}, "\xff\xff\xff\xff not deflate at all", 0));
}

/// As `decode`, with the DEFLATE decoder named: zlib's (the platform's
/// zlib_inflate capability) or Zig's std.compress.flate, which decodes
/// gzip and deflate where the platform lacks the capability.
fn decodeWith(inflater: cc.Inflater, codings: []const cc.Coding, encoded: []const u8, chunk: usize) cc.Error![]u8 {
    const decoder = try cc.Decoder.createWith(testing.allocator, codings, .{ .inflater = inflater });
    defer decoder.destroy();
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    var collect: cc.Collect = .{ .allocator = testing.allocator, .out = &out };
    var at: usize = 0;
    const step = if (chunk == 0) encoded.len else chunk;
    while (at < encoded.len) : (at += step) try decoder.push(encoded[at..@min(at + step, encoded.len)], collect.sink());
    return out.toOwnedSlice(testing.allocator);
}

test "gzip and deflate decode the same with zlib's inflater and with Zig's" {
    const small_text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(small_text);
    const big_text = try fixtures.big(testing.allocator);
    defer testing.allocator.free(big_text);
    const cases = [_]struct { codings: []const cc.Coding, bytes: []const u8, text: []const u8 }{
        .{ .codings = &.{.gzip}, .bytes = fixtures.small_gz, .text = small_text },
        .{ .codings = &.{.deflate}, .bytes = fixtures.small_zlib, .text = small_text },
        .{ .codings = &.{.deflate}, .bytes = fixtures.small_deflate, .text = small_text },
        .{ .codings = &.{ .gzip, .gzip }, .bytes = fixtures.small_gz_gz, .text = small_text },
        .{ .codings = &.{.gzip}, .bytes = fixtures.big_gz, .text = big_text },
    };
    const inflaters: []const cc.Inflater = if (cc.zlib_inflate_supported) &.{ .zlib, .zig } else &.{.zig};
    for (inflaters) |inflater| {
        for (cases) |case| {
            for ([_]usize{ 0, 1, 7, 4096 }) |chunk| {
                const got = try decodeWith(inflater, case.codings, case.bytes, chunk);
                defer testing.allocator.free(got);
                try testing.expect(std.mem.eql(u8, case.text, got));
            }
        }
        var bad = fixtures.small_zlib.*;
        bad[bad.len - 1] ^= 0x01;
        try testing.expectError(error.InvalidData, decodeWith(inflater, &.{.deflate}, &bad, 0));
        try testing.expectError(error.InvalidData, decodeWith(inflater, &.{.deflate}, "\xff\xff\xff\xff not deflate at all", 0));
        try testing.expectError(error.InvalidData, decodeWith(inflater, &.{.gzip}, "not actually gzip", 0));
    }
    // The testing platform has the capability: Fetch's gzip is zlib's.
    try testing.expect(cc.zlib_inflate_supported);
    try testing.expectEqual(cc.Inflater.zlib, cc.Inflater.preferred);
}

/// A zstd frame: `descriptor` and `window` (Window_Descriptor), then one
/// raw last block holding `content`.
fn zstdRawFrame(buf: []u8, window: u8, content: []const u8) []const u8 {
    const magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };
    @memcpy(buf[0..4], &magic);
    buf[4] = 0x00; // no Frame_Content_Size, not single segment, no checksum, no dictionary
    buf[5] = window;
    const header: u24 = @intCast(1 | (0 << 1) | (content.len << 3));
    std.mem.writeInt(u24, buf[6..9], header, .little);
    @memcpy(buf[9..][0..content.len], content);
    return buf[0 .. 9 + content.len];
}

test "zstd: a window over 8 MiB fails (RFC 9659), one of 8 MiB decodes" {
    var buf: [64]u8 = undefined;
    // Window_Descriptor: exponent 13 -> 1 << 23 = 8 MiB; exponent 14 -> 16 MiB;
    // 8 MiB plus an eighth (mantissa 1) is over too.
    try expectDecodes("raw block", &.{.zstd}, zstdRawFrame(&buf, 13 << 3, "raw block"), 0);
    try testing.expectError(error.InvalidData, decode(&.{.zstd}, zstdRawFrame(&buf, 14 << 3, "raw block"), 0));
    try testing.expectError(error.InvalidData, decode(&.{.zstd}, zstdRawFrame(&buf, 13 << 3 | 1, "raw block"), 0));
}

test "zstd: frames follow each other, skippable frames are skipped, junk after a frame fails" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    const skippable = [_]u8{ 0x5a, 0x2a, 0x4d, 0x18, 3, 0, 0, 0, 'a', 'b', 'c' };
    const twice = try std.mem.concat(testing.allocator, u8, &.{ fixtures.small_zst, &skippable, fixtures.small_check_zst });
    defer testing.allocator.free(twice);
    const expected = try std.mem.concat(testing.allocator, u8, &.{ text, text });
    defer testing.allocator.free(expected);
    for ([_]usize{ 0, 1, 9 }) |chunk| try expectDecodes(expected, &.{.zstd}, twice, chunk);
    try testing.expectError(error.InvalidData, decode(&.{.zstd}, fixtures.small_zst ++ "junk", 0));
    // An RLE block: one byte, 5 times.
    const rle = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00, 0x03 | (5 << 3), 0, 0, 'z' };
    try expectDecodes("zzzzz", &.{.zstd}, &rle, 0);
}

test "zstd: a wrong Content_Checksum fails, as libzstd checks it" {
    var bad = fixtures.small_check_zst.*;
    bad[bad.len - 1] ^= 0x01;
    try testing.expectError(error.InvalidData, decode(&.{.zstd}, &bad, 0));
}

test "no truncation or corruption of an encoded body crashes a decoder" {
    const cases = [_]struct { coding: cc.Coding, bytes: []const u8 }{
        .{ .coding = .gzip, .bytes = fixtures.small_gz },
        .{ .coding = .deflate, .bytes = fixtures.small_zlib },
        .{ .coding = .deflate, .bytes = fixtures.small_deflate },
        .{ .coding = .br, .bytes = fixtures.small_br },
        .{ .coding = .zstd, .bytes = fixtures.small_zst },
        .{ .coding = .zstd, .bytes = fixtures.small_check_zst },
    };
    var buf: [512]u8 = undefined;
    for (cases) |case| {
        for (0..case.bytes.len) |len| {
            if (decode(&.{case.coding}, case.bytes[0..len], 0)) |got| testing.allocator.free(got) else |_| {}
        }
        for (0..case.bytes.len) |at| {
            for ([_]u8{ 0x01, 0x80, 0xff }) |flip| {
                const bytes = buf[0..case.bytes.len];
                @memcpy(bytes, case.bytes);
                bytes[at] ^= flip;
                if (decode(&.{case.coding}, bytes, 0)) |got| testing.allocator.free(got) else |_| {}
                if (decode(&.{case.coding}, bytes, 3)) |got| testing.allocator.free(got) else |_| {}
            }
        }
    }
}

// ---------------------------------------------------------------------------
// The network
// ---------------------------------------------------------------------------

fn get(url: []const u8) NetworkRequest {
    return .{ .url = url, .method = "GET", .headers = &.{}, .body = null };
}

/// The answer to a GET of `head` and `body` from a canned server.
fn sendCanned(head: []const u8, body: []const u8) NetworkError!NetworkResponse {
    const response_bytes = fixtures.httpResponse(testing.allocator, head, body) catch return NetworkError.OutOfMemory;
    defer testing.allocator.free(response_bytes);
    var server: fixtures.Canned = .{ .response = response_bytes };
    server.start() catch return NetworkError.Unknown;
    defer server.stop();
    var url_buf: [64]u8 = undefined;
    const request = get(server.url(&url_buf, "/x") catch unreachable);
    const backend = network.LibcurlBackend.init(testing.allocator) catch return NetworkError.Unknown;
    defer backend.deinit();
    return backend.getBackend().send(testing.allocator, &request);
}

test "the network's response carries the decoded body and the encoded size" {
    const text = try fixtures.small(testing.allocator);
    defer testing.allocator.free(text);
    var response = try sendCanned("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n", fixtures.small_gz);
    defer response.deinit();
    try testing.expectEqualStrings(text, response.body orelse "");
    try testing.expectEqual(@as(?u64, fixtures.small_gz.len), response.encoded_body_size);
}

test "a body the coding cannot decode is a network error: ContentDecodingFailed" {
    try testing.expectError(NetworkError.ContentDecodingFailed, sendCanned("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n", "not actually gzip"));
    // More codings than a chain nests (Chromium's ERR_CONTENT_DECODING_INIT_FAILED).
    try testing.expectError(NetworkError.ContentDecodingFailed, sendCanned("HTTP/1.1 200 OK\r\nContent-Encoding: gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip,gzip\r\n", fixtures.small_gz));
}

test "an unknown coding passes the body through; a redirect's body is never decoded" {
    var passed = try sendCanned("HTTP/1.1 200 OK\r\nContent-Encoding: gzip, foo\r\n", fixtures.small_gz);
    defer passed.deinit();
    try testing.expectEqualStrings(fixtures.small_gz, passed.body orelse "");
    // Fetch follows the redirect itself and never reads its body, as
    // Chromium never sets up a redirect's source stream.
    var redirect = try sendCanned("HTTP/1.1 302 Found\r\nLocation: /elsewhere\r\nContent-Encoding: gzip\r\n", "not actually gzip");
    defer redirect.deinit();
    try testing.expectEqual(@as(u16, 302), redirect.status);
}

test "a streamed body reports its encoded size before it ends" {
    try network.globalInit();
    defer network.globalCleanup();
    const text = try fixtures.big(testing.allocator);
    defer testing.allocator.free(text);
    const response_bytes = try fixtures.httpResponse(testing.allocator, "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n", fixtures.big_gz);
    defer testing.allocator.free(response_bytes);
    var server: fixtures.Canned = .{ .response = response_bytes };
    try server.start();
    defer server.stop();
    var scheduler = network.NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();
    var url_buf: [64]u8 = undefined;
    const request = get(try server.url(&url_buf, "/big.text.gz"));
    var record: Record = .{};
    defer record.bytes.deinit(testing.allocator);
    _ = try scheduler.startStreaming(testing.allocator, &request, .{ .context = &record, .head = Record.head, .data = Record.data, .end = Record.end, .encoded = Record.encoded });
    const deadline = clock.monotonicMillis() + 10_000;
    while (!record.ended and clock.monotonicMillis() < deadline) {
        _ = scheduler.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expect(record.ended);
    try testing.expectEqual(@as(?NetworkError, null), record.end_error);
    try testing.expect(std.mem.eql(u8, text, record.bytes.items));
    try testing.expectEqual(@as(u64, fixtures.big_gz.len), record.encoded_at_end);
}

const Record = struct {
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    ended: bool = false,
    end_error: ?NetworkError = null,
    encoded_total: u64 = 0,
    encoded_at_end: u64 = 0,

    fn head(_: ?*anyopaque, response: NetworkResponse) void {
        var r = response;
        r.deinit();
    }

    fn data(context: ?*anyopaque, bytes: []const u8) void {
        const self: *Record = @ptrCast(@alignCast(context.?));
        self.bytes.appendSlice(testing.allocator, bytes) catch {};
    }

    fn encoded(context: ?*anyopaque, total: u64) void {
        const self: *Record = @ptrCast(@alignCast(context.?));
        self.encoded_total = total;
    }

    fn end(context: ?*anyopaque, result: NetworkError!void) void {
        const self: *Record = @ptrCast(@alignCast(context.?));
        self.ended = true;
        self.encoded_at_end = self.encoded_total;
        result catch |err| {
            self.end_error = err;
        };
    }
};

test "HTTP-network fetch records the body info's encoded and decoded sizes from the network's answer" {
    const allocator = testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "http://example.test/resource");
    defer request.deinit();
    const controller = try fetch.internal.FetchController.init(allocator);
    defer controller.deinit();
    var timing = fetch.internal.FetchTimingInfo.init(allocator);
    defer timing.deinit();
    const params = try fetch.internal.FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();
    var headers = [_]Header{.{ .name = "Content-Encoding", .value = "gzip" }};
    const answer = NetworkResponse{
        .allocator = allocator,
        .status = 200,
        .http_version = .http_1_1,
        .headers = &headers,
        .body = "decoded",
        .encoded_body_size = 57,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
    const response = try fetch.algorithms.http_fetch.httpNetworkFetchFinish(allocator, params, &answer, 10, null);
    defer response.deinit();
    try testing.expectEqual(@as(u64, 57), response.body_info.encoded_size);
    try testing.expectEqual(@as(u64, 7), response.body_info.decoded_size);
    try testing.expectEqualStrings("gzip", response.body_info.content_encoding);
}

//! The WebSocket opening handshake over HTTP/1.1 as kit/curl's transport
//! makes and checks it (lane net3; RFC 6455 4.1): the request carries the
//! fields libcurl's upgrade sent, the response head is read as the browsers
//! read an HTTP/1 head, and a 101 is accepted only with Upgrade, Connection
//! and the right Sec-WebSocket-Accept, and no extension (libcurl checked
//! none of these: lib/ws.c Curl_ws_accept only comments on them).
const std = @import("std");
const testing = std.testing;
const handshake = @import("kit_curl_share").websocket_handshake;

test "Sec-WebSocket-Accept is RFC 6455 1.3's example" {
    try testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", &handshake.acceptFor("dGhlIHNhbXBsZSBub25jZQ=="));
    const key = handshake.keyFrom("the sample nonce".*);
    try testing.expectEqualStrings("dGhlIHNhbXBsZSBub25jZQ==", &key);
}

test "the request has libcurl's fields, then the caller's, then the URL's credentials" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try handshake.writeRequest(testing.allocator, &out, .{ .host = "web-platform.test", .port = 8666, .resource = "/echo?x=1" }, "dGhlIHNhbXBsZSBub25jZQ==", "Crane/0.1", "Basic Zm9vOmJhcg==", &.{
        .{ .name = "Origin", .value = "http://web-platform.test:8000" },
        .{ .name = "Sec-WebSocket-Protocol", .value = "echo, chat" },
    });
    try testing.expectEqualStrings("GET /echo?x=1 HTTP/1.1\r\n" ++
        "Host: web-platform.test:8666\r\n" ++
        "User-Agent: Crane/0.1\r\n" ++
        "Accept: */*\r\n" ++
        "Upgrade: websocket\r\n" ++
        "Connection: Upgrade\r\n" ++
        "Sec-WebSocket-Version: 13\r\n" ++
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" ++
        "Origin: http://web-platform.test:8000\r\n" ++
        "Sec-WebSocket-Protocol: echo, chat\r\n" ++
        "Authorization: Basic Zm9vOmJhcg==\r\n" ++
        "\r\n", out.items);

    out.clearRetainingCapacity();
    try handshake.writeRequest(testing.allocator, &out, .{ .host = "[::1]", .port = null, .resource = "/" }, "k", null, "Basic eA==", &.{.{ .name = "authorization", .value = "Bearer t" }});
    try testing.expectEqualStrings("GET / HTTP/1.1\r\nHost: [::1]\r\nAccept: */*\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: k\r\nauthorization: Bearer t\r\n\r\n", out.items);
}

test "the head ends at an empty line, after CRLF or a lone LF" {
    try testing.expectEqual(@as(?usize, null), handshake.headEnd("HTTP/1.1 101 Switching\r\nUpgrade: websocket\r\n"));
    try testing.expectEqual(@as(?usize, 25), handshake.headEnd("HTTP/1.1 101 OK\r\nA: b\r\n\r\n\x81\x00"));
    try testing.expectEqual(@as(?usize, 22), handshake.headEnd("HTTP/1.1 101 OK\nA: b\n\n\x81"));
}

fn parse(head: []const u8, folded: *std.ArrayList(u8)) !handshake.Head {
    return handshake.parseHead(testing.allocator, head, folded);
}

test "a head is read as the browsers read one" {
    var folded: std.ArrayList(u8) = .empty;
    defer folded.deinit(testing.allocator);
    var head = try parse("HTTP/1.1 101 Switching Protocols\r\nUpgrade:  websocket \r\nno colon here\r\n folded onto nothing\r\nX-Folded: one\r\n\ttwo\r\n: empty name\r\nConnection: Upgrade\r\n\r\n", &folded);
    defer head.deinit(testing.allocator);
    try testing.expectEqual(@as(u16, 101), head.status);
    try testing.expectEqual(@as(usize, 3), head.fields.items.len);
    try testing.expectEqualStrings("websocket", head.single("upgrade").?);
    try testing.expectEqualStrings("one two", head.single("X-Folded").?);
    try testing.expectEqualStrings("Upgrade", head.single("Connection").?);

    for ([_][]const u8{
        "HTTP/1.1 101 OK\r\nX: a\x00b\r\n\r\n",
        "HTTP/2 101 OK\r\n\r\n",
        "HTTP/1.1 10 OK\r\n\r\n",
        "HTTP/1.1 1011\r\n\r\n",
        "ICY 200 OK\r\n\r\n",
    }) |bad| try testing.expectError(error.InvalidResponse, parse(bad, &folded));
    var bare = try parse("HTTP/1.1 101\r\n\r\n", &folded);
    defer bare.deinit(testing.allocator);
    try testing.expectEqual(@as(u16, 101), bare.status);
}

test "a 101 is accepted only as RFC 6455 4.1 says" {
    const key = "dGhlIHNhbXBsZSBub25jZQ==";
    const good = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: WebSocket\r\nConnection: keep-alive, Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n";
    var folded: std.ArrayList(u8) = .empty;
    defer folded.deinit(testing.allocator);
    {
        var head = try parse(good, &folded);
        defer head.deinit(testing.allocator);
        try testing.expect(handshake.accepts(&head, key));
    }
    for ([_][]const u8{
        "HTTP/1.1 200 OK\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
        "HTTP/1.1 101 OK\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
        "HTTP/1.1 101 OK\r\nUpgrade: websocket, h2\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
        "HTTP/1.1 101 OK\r\nUpgrade: websocket\r\nConnection: keep-alive\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
        "HTTP/1.1 101 OK\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: xxxxLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
        "HTTP/1.1 101 OK\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n",
        "HTTP/1.1 101 OK\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n",
        "HTTP/1.1 101 OK\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\nSec-WebSocket-Extensions: permessage-deflate\r\n\r\n",
    }) |bad| {
        var head = try parse(bad, &folded);
        defer head.deinit(testing.allocator);
        try testing.expect(!handshake.accepts(&head, key));
    }
}

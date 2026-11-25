//! Lane prescan1: streaming HTML parsing while the meta charset prescan runs
//! (Blink's TextResourceDecoder::Decode + Document::SetEncodingData model;
//! HTML §13.2.3.2 step 3 & §13.2.3.4 step 5).
//!
//! Each chunk of a `text/html` body without an HTTP charset is decoded and
//! parsed as soon as BOM and XML-declaration checks finish, rather than
//! waiting for 1024 bytes or EOF. The meta charset scanner runs chunk by chunk
//! ahead of decoding so a late `<meta charset>` switches the decoder on the
//! fly, updates `document.characterSet`, and re-decodes an already-parsed
//! `<title>` when non-ASCII bytes were tentatively decoded as windows-1252.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");

const DocumentParser = html.scripted_parser.DocumentParser;
const ByteStream = html.scripted_parser.ByteStream;
const PipeSource = fetch.internal.PipeSource;
const StreamedBody = @import("html_core").navigation.fetch_integration.StreamedBody;

const Network = struct {
    source: *PipeSource,
    cancelled: bool = false,

    fn cancel(context: *anyopaque) void {
        const self: *Network = @ptrCast(@alignCast(context));
        self.cancelled = true;
    }

    fn holderAlive(_: *anyopaque) bool {
        return true;
    }

    fn open(self: *Network) !*StreamedBody {
        self.source = try PipeSource.create(testing.allocator);
        self.source.producer = .{ .context = self, .cancel = &cancel };
        const pipe = try self.source.branch();
        return StreamedBody.create(testing.allocator, pipe, .{ .context = self, .alive = &holderAlive });
    }
};

const Realm = struct {
    ctx: runtime.ContextData,

    fn init(self: *Realm) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(testing.allocator, .{});
    }

    fn deinit(self: *Realm) void {
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

fn streamingDocument(realm: *Realm, pipe: *StreamedBody, stream: ByteStream) !struct { *runtime.Instance, *DocumentParser } {
    const document = try interfaces.Document.initWith(testing.allocator, &realm.ctx, .{ .ready_state = ._loading_ });
    errdefer interfaces.Document.deinit(document);
    const parser = try DocumentParser.createStreaming(testing.allocator, &realm.ctx, document, .{
        .byte_stream = stream,
        .body_stream = pipe,
    });
    try testing.expect(dom.document_lifecycle.associateParser(document, parser));
    parser.release();
    return .{ document, parser };
}

fn textOf(document: *runtime.Instance, id: []const u8) !?[]u8 {
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse return null;
    var content = (try interfaces.Node.get_textContent(element)) orelse return null;
    defer content.deinit(element.ctx.allocator);
    return try testing.allocator.dupe(u8, content.asSlice());
}

fn expectText(document: *runtime.Instance, id: []const u8, expected: ?[]const u8) !void {
    const actual = try textOf(document, id);
    defer if (actual) |a| testing.allocator.free(a);
    if (expected) |e| {
        try testing.expect(actual != null);
        try testing.expectEqualStrings(e, actual.?);
    } else try testing.expect(actual == null);
}

fn expectTitle(document: *runtime.Instance, expected: []const u8) !void {
    var title = try interfaces.Document.get_title(document);
    defer title.deinit(document.ctx.allocator);
    try testing.expectEqualStrings(expected, title.asSlice());
}

fn expectCharset(document: *runtime.Instance, expected: []const u8) !void {
    const actual = dom.document_internals.getEncoding(document) orelse "";
    try testing.expectEqualStrings(expected, actual);
}

fn parserOf(document: *runtime.Instance) ?*anyopaque {
    return dom.document_internals.getInternal(document).?.active_parser;
}

test "prescan1: a small first chunk (<1024 B) with no HTTP charset parses before EOF" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
    defer interfaces.Document.deinit(document);

    // 60 bytes — far below 1024, no <meta charset>, body still open.
    network.source.push("<!doctype html><title>streamed</title><p id=first>first</p>");
    parser.readNetworkInput();

    // Must already be parsed into the DOM while the document is still loading.
    try expectTitle(document, "streamed");
    try expectText(document, "first", "first");
    try expectText(document, "last", null);
    try expectCharset(document, "windows-1252");
    try testing.expect(parserOf(document) != null);

    network.source.push("<p id=last>last</p>");
    network.source.finish();
    parser.readNetworkInput();
    try expectText(document, "last", "last");
    try testing.expect(parserOf(document) == null);
}

test "prescan1: late meta charset in chunk 2 switches tentative encoding on the fly" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><head><title>early</title>");
    parser.readNetworkInput();
    try expectTitle(document, "early");
    try expectCharset(document, "windows-1252");

    // Chunk 2 declares windows-1251: 0xE9 is U+0439 (Cyrillic short i).
    network.source.push("<meta charset=windows-1251></head><body><p id=a>\xE9</p>");
    parser.readNetworkInput();
    try expectCharset(document, "windows-1251");
    try expectText(document, "a", "\u{439}");

    // Chunk 3 continues using windows-1251 (0xE6 is U+0436).
    network.source.push("<p id=b>\xE6</p></body>");
    network.source.finish();
    parser.readNetworkInput();
    try expectText(document, "b", "\u{436}");
    try testing.expect(parserOf(document) == null);
}

test "prescan1: late meta charset after non-head + 1024 bytes is ignored" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
    defer interfaces.Document.deinit(document);

    var pad: [1050]u8 = undefined;
    @memset(&pad, 'a');
    network.source.push("<!doctype html></head><p id=pad>");
    network.source.push(&pad);
    network.source.push("</p>");
    parser.readNetworkInput();
    try expectCharset(document, "windows-1252");

    // Past 1024 characters after </head>: scanner already stopped.
    network.source.push("<meta charset=windows-1251><p id=a>\xE9</p>");
    network.source.finish();
    parser.readNetworkInput();
    try expectCharset(document, "windows-1252");
    try expectText(document, "a", "\u{E9}");
}

test "prescan1: non-ASCII in <title> before late meta charset is re-decoded" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    // Case 1: single-byte windows-1251 (0xE6 -> U+0436).
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
        defer interfaces.Document.deinit(document);

        network.source.push("<!doctype html><head><title>\xE6</title>");
        parser.readNetworkInput();
        // Tentatively decoded as windows-1252.
        try expectTitle(document, "\u{E6}");
        try expectCharset(document, "windows-1252");

        network.source.push("<meta charset=windows-1251></head><body><p id=a>\xE6</p>");
        network.source.finish();
        parser.readNetworkInput();
        try expectCharset(document, "windows-1251");
        try expectTitle(document, "\u{436}");
        try expectText(document, "a", "\u{436}");
    }

    // Case 2: UTF-8 including a byte in 0x80..0x9F (Euro sign: E2 82 AC).
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
        defer interfaces.Document.deinit(document);

        network.source.push("<!doctype html><head><title>caf\xC3\xA9 \xE2\x82\xAC</title>");
        parser.readNetworkInput();
        try expectCharset(document, "windows-1252");

        network.source.push("<meta charset=utf-8></head><body><p id=a>caf\xC3\xA9 \xE2\x82\xAC</p>");
        network.source.finish();
        parser.readNetworkInput();
        try expectCharset(document, "UTF-8");
        try expectTitle(document, "caf\u{E9} \u{20AC}");
        try expectText(document, "a", "caf\u{E9} \u{20AC}");
    }

    // Case 3: ASCII-only chunk 1 with a character reference in <title> must not be corrupted.
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
        defer interfaces.Document.deinit(document);

        network.source.push("<!doctype html><head><title>caf&eacute;</title>");
        parser.readNetworkInput();
        try expectTitle(document, "caf\u{E9}");

        network.source.push("<meta charset=utf-8></head><body><p id=a>ok</p>");
        network.source.finish();
        parser.readNetworkInput();
        try expectCharset(document, "UTF-8");
        try expectTitle(document, "caf\u{E9}");
    }
}

test "prescan1: BOM precedence over HTTP Content-Type and meta charset, including split BOM" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    // UTF-8 BOM split across three 1-byte chunks beats HTTP windows-1251 and meta windows-1251.
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html; charset=windows-1251" });
        defer interfaces.Document.deinit(document);

        network.source.push("\xEF");
        parser.readNetworkInput();
        network.source.push("\xBB");
        parser.readNetworkInput();
        network.source.push("\xBF");
        parser.readNetworkInput();
        network.source.push("<!doctype html><meta charset=windows-1251><p id=a>caf\xC3\xA9</p>");
        parser.readNetworkInput();

        try expectCharset(document, "UTF-8");
        try expectText(document, "a", "caf\u{E9}");

        network.source.finish();
        parser.readNetworkInput();
        try testing.expect(parserOf(document) == null);
    }

    // UTF-16LE BOM split across 1-byte chunks beats meta charset.
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
        defer interfaces.Document.deinit(document);

        network.source.push("\xFF");
        parser.readNetworkInput();
        network.source.push("\xFE");
        parser.readNetworkInput();
        const utf16le_body = std.unicode.utf8ToUtf16LeStringLiteral("<p id=a>hi</p>");
        network.source.push(std.mem.sliceAsBytes(utf16le_body));
        network.source.finish();
        parser.readNetworkInput();

        try expectCharset(document, "UTF-16LE");
        try expectText(document, "a", "hi");
    }
}

test "prescan1: HTTP Content-Type charset takes precedence over meta charset and parses immediately" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html; charset=utf-8" });
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><meta charset=windows-1251><p id=a>caf\xC3\xA9</p>");
    parser.readNetworkInput();
    try expectCharset(document, "UTF-8");
    try expectText(document, "a", "caf\u{E9}");
    try testing.expect(parserOf(document) != null);

    network.source.finish();
    parser.readNetworkInput();
    try testing.expect(parserOf(document) == null);
}

test "prescan1: XML declaration buffered until '>' and overridden by meta charset; UTF-16 XML decl is certain" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    // Split <?xml ...?> across chunks, then overridden by a later <meta charset=windows-1253>.
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
        defer interfaces.Document.deinit(document);

        network.source.push("<?xml version=\"1.0\" ");
        parser.readNetworkInput();
        network.source.push("encoding=\"windows-1251\"?>");
        parser.readNetworkInput();
        try expectCharset(document, "windows-1251");

        // Meta charset overrides XML declaration (windows-1253: 0xE6 -> Greek zeta U+03B6).
        network.source.push("<meta charset=windows-1253><p id=a>\xE6</p>");
        network.source.finish();
        parser.readNetworkInput();
        try expectCharset(document, "windows-1253");
        try expectText(document, "a", "\u{3B6}");
    }

    // UTF-16LE <?x split across chunks decides UTF-16LE and skips meta scan.
    {
        var network: Network = .{ .source = undefined };
        const pipe = try network.open();
        const document, const parser = try streamingDocument(&realm, pipe, .{ .content_type = "text/html" });
        defer interfaces.Document.deinit(document);

        const body = std.unicode.utf8ToUtf16LeStringLiteral("<?xml version=\"1.0\"?><p id=a>ok</p>");
        const raw = std.mem.sliceAsBytes(body);
        network.source.push(raw[0..4]);
        parser.readNetworkInput();
        network.source.push(raw[4..]);
        network.source.finish();
        parser.readNetworkInput();
        try expectCharset(document, "UTF-16LE");
        try expectText(document, "a", "ok");
    }
}

test "prescan1: same-origin parent encoding is used immediately and overridden by late meta charset" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    var network: Network = .{ .source = undefined };
    const pipe = try network.open();
    const document, const parser = try streamingDocument(&realm, pipe, .{
        .content_type = "text/html",
        .parent_encoding = "windows-1251",
    });
    defer interfaces.Document.deinit(document);

    network.source.push("<!doctype html><head><title>hi</title>");
    parser.readNetworkInput();
    try expectTitle(document, "hi");
    try expectCharset(document, "windows-1251");

    network.source.push("<meta charset=utf-8></head><body><p id=a>caf\xC3\xA9</p>");
    network.source.finish();
    parser.readNetworkInput();
    try expectCharset(document, "UTF-8");
    try expectText(document, "a", "caf\u{E9}");
}

test "prescan1: mayStartXmlDeclaration and windows1252Reverse unit checks" {
    const sniffing = @import("html_core").parser.encoding_sniffing;

    // mayStartXmlDeclaration: prefixes of <?xml and UTF-16 <?x wait; normal HTML does not.
    try testing.expect(sniffing.mayStartXmlDeclaration(""));
    try testing.expect(sniffing.mayStartXmlDeclaration("<"));
    try testing.expect(sniffing.mayStartXmlDeclaration("<?"));
    try testing.expect(sniffing.mayStartXmlDeclaration("<?xm"));
    try testing.expect(sniffing.mayStartXmlDeclaration("<?xml version=\"1.0\""));
    try testing.expect(!sniffing.mayStartXmlDeclaration("<?xml version=\"1.0\"?>"));
    try testing.expect(sniffing.mayStartXmlDeclaration("\x3C\x00\x3F\x00\x78"));
    try testing.expect(!sniffing.mayStartXmlDeclaration("\x3C\x00\x3F\x00\x78\x00"));
    try testing.expect(sniffing.mayStartXmlDeclaration("\x00\x3C\x00\x3F\x00"));
    try testing.expect(!sniffing.mayStartXmlDeclaration("\x00\x3C\x00\x3F\x00\x78"));
    try testing.expect(!sniffing.mayStartXmlDeclaration("<!"));
    try testing.expect(!sniffing.mayStartXmlDeclaration("<p"));

    // windows1252Reverse: exact 256-byte round trip through windows-1252 decode.
    var all_bytes: [256]u8 = undefined;
    for (0..256) |i| all_bytes[i] = @intCast(i);
    const decoded = try sniffing.decodeWith(testing.allocator, &all_bytes, sniffing.windows_1252);
    defer testing.allocator.free(decoded);
    const reversed = (try sniffing.windows1252Reverse(testing.allocator, decoded)) orelse return error.TestUnexpectedResult;
    defer testing.allocator.free(reversed);
    try testing.expectEqualSlices(u8, &all_bytes, reversed);

    // Code points outside windows-1252 (e.g. Cyrillic / CJK) return null.
    try testing.expect((try sniffing.windows1252Reverse(testing.allocator, "\u{0436}")) == null);
    try testing.expect((try sniffing.windows1252Reverse(testing.allocator, "abc\u{4E2D}")) == null);
}
